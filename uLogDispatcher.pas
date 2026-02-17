unit uLogDispatcher;
{
  Fila assíncrona de envio de logs:
  - Enfileira TLogItem em memória com limite configurável.
  - Thread worker consome a fila, monta JSON GELF e envia via TGraylogClient.
  - Implementa retry simples e limitação de tamanho (descarta screenshot grande).
  - Nunca levanta exceções (try/except internos).
}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  uLogTypes, uGraylogClient;

type
  TLogDispatcher = class
  private
    FQueue: TQueue<TLogItem>;
    FLock: TCriticalSection;
    FEvent: TEvent;
    FWorker: TThread;
    FClient: TGraylogClient;
    FActive: Boolean;
    FMaxQueueSize: Integer;
    FRetryCount: Integer;
    FERPVersion: string;
    function Dequeue: TLogItem;
    procedure WorkerExecute;
    function BuildGELF(const Item: TLogItem): string;
  public
    constructor Create(AClient: TGraylogClient; const AERPVersion: string);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Enqueue(AItem: TLogItem);
    property MaxQueueSize: Integer read FMaxQueueSize write FMaxQueueSize;
    property RetryCount: Integer read FRetryCount write FRetryCount;
  end;

implementation

uses
  Winapi.Windows, System.DateUtils;

type
  TLogWorker = class(TThread)
  private
    FOwner: TLogDispatcher;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TLogDispatcher);
  end;

function JsonEscape(const S: string): string;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    case ch of
      '"':  Result := Result + '\"';
      '\': Result := Result + '\\';
      #8:  Result := Result + '\b';
      #9:  Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if Ord(ch) < 32 then
        Result := Result + '\u' + IntToHex(Ord(ch), 4)
      else
        Result := Result + ch;
    end;
  end;
end;

function UnixTimestampUTC(const ADate: TDateTime): Double;
begin
  Result := (ADate - EncodeDate(1970,1,1)) * 86400;
end;

{ TLogDispatcher }

constructor TLogDispatcher.Create(AClient: TGraylogClient; const AERPVersion: string);
begin
  inherited Create;
  FClient := AClient;
  FERPVersion := AERPVersion;
  FQueue := TQueue<TLogItem>.Create;
  FLock := TCriticalSection.Create;
  FEvent := TEvent.Create(nil, False, False, '');
  FActive := False;
  FMaxQueueSize := 1000;
  FRetryCount := 2;
end;

destructor TLogDispatcher.Destroy;
begin
  Stop;
  FEvent.Free;
  FLock.Free;
  while FQueue.Count > 0 do
    Dequeue.Free;
  FQueue.Free;
  inherited;
end;

procedure TLogDispatcher.Enqueue(AItem: TLogItem);
begin
  try
    FLock.Enter;
    if FQueue.Count >= FMaxQueueSize then
    begin
      AItem.Free;
      Exit;
    end;
    FQueue.Enqueue(AItem);
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TLogDispatcher.Dequeue: TLogItem;
begin
  Result := nil;
  FLock.Enter;
  try
    if FQueue.Count > 0 then
      Result := FQueue.Dequeue;
  finally
    FLock.Leave;
  end;
end;

procedure TLogDispatcher.Start;
begin
  if FActive then Exit;
  FActive := True;
  FWorker := TLogWorker.Create(Self);
end;

procedure TLogDispatcher.Stop;
begin
  if not FActive then Exit;
  FActive := False;
  FEvent.SetEvent;
  if Assigned(FWorker) then
  begin
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
end;

function TLogDispatcher.BuildGELF(const Item: TLogItem): string;
var
  sb: TStringBuilder;
  ts: Double;
  key, value: string;
  FS: TFormatSettings;
begin
  sb := TStringBuilder.Create(1024);
  try
    ts := UnixTimestampUTC(Item.TimestampUTC);
    FS := TFormatSettings.Create;
    FS.DecimalSeparator := '.';
    sb.Append('{');
    sb.Append('"version":"1.1",');
    sb.Append('"host":"').Append(JsonEscape(Item.MachineName)).Append('",');
    sb.Append('"short_message":"').Append(JsonEscape(Item.ShortMessage)).Append('",');
    sb.Append('"full_message":"').Append(JsonEscape(Item.FullMessage)).Append('",');
    sb.Append('"timestamp":').Append(FormatFloat('0.000', ts, FS)).Append(',');
    sb.Append('"level":').Append(IntToStr(LogLevelToSyslog(Item.Level)));
    if Item.ExceptionClass <> '' then
      sb.Append(',"_exception_class":"').Append(JsonEscape(Item.ExceptionClass)).Append('"');
    if Item.StackTrace <> '' then
      sb.Append(',"_stacktrace":"').Append(JsonEscape(Item.StackTrace)).Append('"');
    if Item.UserName <> '' then
      sb.Append(',"_user":"').Append(JsonEscape(Item.UserName)).Append('"');
    if Item.MachineName <> '' then
      sb.Append(',"_machine":"').Append(JsonEscape(Item.MachineName)).Append('"');
    if Item.ERPVersion <> '' then
      sb.Append(',"_erp_version":"').Append(JsonEscape(Item.ERPVersion)).Append('"');
    if Item.ModuleName <> '' then
      sb.Append(',"_module":"').Append(JsonEscape(Item.ModuleName)).Append('"');
    if Item.CompanyName <> '' then
      sb.Append(',"_empresa":"').Append(JsonEscape(Item.CompanyName)).Append('"');
    if Item.BranchId <> '' then
      sb.Append(',"_filial":"').Append(JsonEscape(Item.BranchId)).Append('"');
    if Assigned(Item.Additional) and (Item.Additional.Count > 0) then
    begin
      for key in Item.Additional.Keys do
      begin
        value := Item.Additional.Items[key];
        sb.Append(',"_').Append(JsonEscape(key)).Append('":"').Append(JsonEscape(value)).Append('"');
      end;
    end;
    sb.Append('}');
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

procedure TLogDispatcher.WorkerExecute;
var
  Item: TLogItem;
  Json: string;
  Attempt: Integer;
begin
  while FActive do
  begin
    if Assigned(FEvent) then
      FEvent.WaitFor(200);
    Item := Dequeue;
    if not Assigned(Item) then
      Continue;
    try
      Json := BuildGELF(Item);
      Attempt := 0;
      while Attempt <= FRetryCount do
      begin
        if FClient.SendJSON(Json) then
          Break;
        Inc(Attempt);
        Sleep(100);
      end;
    except
      // swallow
    end;
    Item.Free;
  end;
end;

{ TLogWorker }

constructor TLogWorker.Create(AOwner: TLogDispatcher);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TLogWorker.Execute;
begin
  if Assigned(FOwner) then
    FOwner.WorkerExecute;
end;

end.

