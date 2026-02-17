unit uExceptionLogger;

interface

uses
  System.SysUtils, Vcl.Forms, uLogTypes;

type
  TExceptionLogger = class
  private
    class var FDispatcher: TObject;
    class var FClient: TObject;
    class var FInitialized: Boolean;
    class var FERPVersion: string;
    class var FCompanyName: string;
    class var FBranchId: string;
    class var FPrevOnException: TExceptionEvent;
    class function GetMachineName: string; static;
    class function GetUserName: string; static;
    class function GetModuleName: string; static;
  public
    class procedure Initialize(const GraylogHost: string; GraylogPort: Integer; const ERPVersion, CompanyName,
      BranchId: string; Protocol: TTransportProtocol = tpUDP);
    class procedure FinalizeLogger;
    class procedure HandleException(Sender: TObject; E: Exception);
    class procedure LogMessage(const Level: TLogLevel; const ShortMsg, FullMsg: string);
  end;

implementation

uses
  Winapi.Windows, uStackTraceHelper, uScreenshotHelper, uGraylogClient, uLogDispatcher,
  System.Classes, uLocalLog;

class function TExceptionLogger.GetMachineName: string;
var
  Buffer: array [0..MAX_COMPUTERNAME_LENGTH + 1] of Char;
  Size: DWORD;
begin
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  if GetComputerName(Buffer, Size) then
    Result := Buffer
  else
    Result := '';
end;

class function TExceptionLogger.GetModuleName: string;
var
  buf: array[0..MAX_PATH] of Char;
begin
  buf[0] := #0;
  GetModuleFileName(0, buf, MAX_PATH);
  Result := buf;
end;

class function TExceptionLogger.GetUserName: string;
var
  Buffer: array [0..255] of Char;
  Size: DWORD;
begin
  Size := Length(Buffer);
  if Winapi.Windows.GetUserName(Buffer, Size) then
    Result := Buffer
  else
    Result := '';
end;

class procedure TExceptionLogger.Initialize(const GraylogHost: string; GraylogPort: Integer;
  const ERPVersion, CompanyName, BranchId: string; Protocol: TTransportProtocol);
var
  Client: TGraylogClient;
  Dispatcher: TLogDispatcher;
begin
  if FInitialized then Exit;
  try
    FERPVersion := ERPVersion;
    FCompanyName := CompanyName;
    FBranchId := BranchId;
    TStackTraceHelper.Initialize;
    Client := TGraylogClient.Create(GraylogHost, GraylogPort, Protocol);
    Client.ConfigureTimeouts(400, 400);
    Dispatcher := TLogDispatcher.Create(Client, ERPVersion);
    Dispatcher.MaxQueueSize := 1000;
    Dispatcher.RetryCount := 2;
    Dispatcher.Start;
    FClient := Client;
    FDispatcher := Dispatcher;
    FPrevOnException := Application.OnException;
    Application.OnException := HandleException;
    FInitialized := True;
  except
    // ignore
  end;
end;

class procedure TExceptionLogger.FinalizeLogger;
begin
  try
    if Assigned(FDispatcher) then
    begin
      TLogDispatcher(FDispatcher).Stop;
      TLogDispatcher(FDispatcher).Free;
      FDispatcher := nil;
    end;
    if Assigned(FClient) then
    begin
      TGraylogClient(FClient).Free;
      FClient := nil;
    end;
    FInitialized := False;
  except
    // ignore
  end;
end;

class procedure TExceptionLogger.HandleException(Sender: TObject; E: Exception);
var
  Item: TLogItem;
  Disp: TLogDispatcher;
begin
  try
    if not FInitialized then Exit;
    if not Assigned(FDispatcher) then Exit;
    Disp := TLogDispatcher(FDispatcher);
    Item := TLogItem.Create;
    Item.TimestampUTC := Now;
    Item.Level := llError;
    Item.ShortMessage := E.ClassName + ': ' + E.Message;
    Item.FullMessage := E.Message;
    Item.ExceptionClass := E.ClassName;
    Item.StackTrace := TStackTraceHelper.CaptureExceptionStack(E);
    Item.UserName := GetUserName;
    Item.MachineName := GetMachineName;
    Item.ERPVersion := FERPVersion;
    Item.ModuleName := GetModuleName;
    Item.CompanyName := FCompanyName;
    Item.BranchId := FBranchId;
    Item.ScreenshotBase64 := TScreenshotHelper.CaptureScreenToBase64JPEG(60, 512*1024);
    Disp.Enqueue(Item);
    try
      TLocalLogHelper.SaveExceptionFiles(Item);
      TLocalLogHelper.PurgeOldLogs(7);
    except
      // ignore
    end;
  except
    // never raise
  end;
  try
    if Assigned(FPrevOnException) then
      FPrevOnException(Sender, E);
  except
    // ignore
  end;
end;

class procedure TExceptionLogger.LogMessage(const Level: TLogLevel; const ShortMsg, FullMsg: string);
var
  Item: TLogItem;
  Disp: TLogDispatcher;
begin
  try
    if not FInitialized then Exit;
    if not Assigned(FDispatcher) then Exit;
    Disp := TLogDispatcher(FDispatcher);
    Item := TLogItem.Create;
    Item.TimestampUTC := Now;
    Item.Level := Level;
    Item.ShortMessage := ShortMsg;
    Item.FullMessage := FullMsg;
    Item.UserName := GetUserName;
    Item.MachineName := GetMachineName;
    Item.ERPVersion := FERPVersion;
    Item.ModuleName := GetModuleName;
    Item.CompanyName := FCompanyName;
    Item.BranchId := FBranchId;
    if Level in [llError, llFatal] then
      Item.ScreenshotBase64 := TScreenshotHelper.CaptureScreenToBase64JPEG(60, 512*1024);
    Disp.Enqueue(Item);
    if Level in [llError, llFatal] then
    begin
      try
        TLocalLogHelper.SaveExceptionFiles(Item);
        TLocalLogHelper.PurgeOldLogs(7);
      except
        // ignore
      end;
    end;
  except
    // ignore
  end;
end;

end.
