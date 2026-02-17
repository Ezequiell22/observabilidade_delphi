unit uLocalLog;

interface

uses
  System.SysUtils, System.Classes, uLogTypes;

type
  TLocalLogHelper = class
  public
    class function LogsDir: string;
    class procedure EnsureLogsDir;
    class procedure PurgeOldLogs(Days: Integer = 7);
    class procedure SaveExceptionFiles(const Item: TLogItem);
  end;

implementation

uses
  Winapi.Windows, System.DateUtils, EncdDecd;

function ReplaceInvalidPDFText(const S: string): AnsiString;
var
  i: Integer;
  ch: Char;
begin
  SetLength(Result, Length(S));
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if Ord(ch) < 32 then
      Result[i] := AnsiChar(' ')
    else if Ord(ch) > 126 then
      Result[i] := AnsiChar('?')
    else
      Result[i] := AnsiChar(ch);
  end;
end;

function EscapePDFParen(const S: AnsiString): AnsiString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    case S[i] of
      '(', ')', '\': Result := Result + '\' + S[i];
    else
      Result := Result + S[i];
    end;
  end;
end;

function ToId(const I: Integer): string;
begin
  Result := IntToStr(I) + ' 0 obj';
end;

class function TLocalLogHelper.LogsDir: string;
var
  Buf: array[0..MAX_PATH] of Char;
  Dir: string;
begin
  GetModuleFileName(0, Buf, MAX_PATH);
  Dir := ExtractFilePath(Buf);
  Result := IncludeTrailingPathDelimiter(Dir) + 'logs_';
end;

class procedure TLocalLogHelper.EnsureLogsDir;
var
  D: string;
begin
  D := LogsDir;
  if not DirectoryExists(D) then
  begin
    try
      ForceDirectories(D);
    except
      // ignore
    end;
  end;
end;

class procedure TLocalLogHelper.PurgeOldLogs(Days: Integer);
var
  SR: TSearchRec;
  Path: string;
  NowDT: TDateTime;
  FileDT: TDateTime;
begin
  try
    Path := IncludeTrailingPathDelimiter(LogsDir) + '*.*';
    NowDT := Now;
    if FindFirst(Path, faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          FileDT := FileDateToDateTime(SR.Time);
          if DaysBetween(NowDT, FileDT) > Days then
          begin
            try
              DeleteFile(IncludeTrailingPathDelimiter(LogsDir) + SR.Name);
            except
              // ignore
            end;
          end;
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  except
    // ignore
  end;
end;

class procedure TLocalLogHelper.SaveExceptionFiles(const Item: TLogItem);
var
  BaseName, TxtName, ImgName: string;
  SL: TStringList;
  B64, Decoded: string;
  ImgStream: TFileStream;
  ImgBytes: TBytes;
begin
  try
    EnsureLogsDir;
    BaseName := FormatDateTime('yyyymmdd_hhnnss', Now) + '_' +
      StringReplace(Item.ExceptionClass, ' ', '_', [rfReplaceAll]);
    TxtName := IncludeTrailingPathDelimiter(LogsDir) + BaseName + '.txt';
    ImgName := IncludeTrailingPathDelimiter(LogsDir) + BaseName + '.jpg';
    SL := TStringList.Create;
    try
      SL.Add('Data/Hora: ' + DateTimeToStr(Item.TimestampUTC));
      SL.Add('Host: ' + Item.MachineName + '  Usuario: ' + Item.UserName);
      SL.Add('ERP: ' + Item.ERPVersion + '  Modulo: ' + Item.ModuleName);
      SL.Add('Classe: ' + Item.ExceptionClass);
      SL.Add('Mensagem: ' + Item.FullMessage);
      SL.Add(' ');
      SL.Add('Stack trace:');
      if Item.StackTrace <> '' then
        SL.Add(Item.StackTrace);
      try
        SL.SaveToFile(TxtName);
      except
        // ignore
      end;
    finally
      SL.Free;
    end;
    B64 := Item.ScreenshotBase64;
    if B64 <> '' then
    try
      Decoded := DecodeBase64(B64);
      SetLength(ImgBytes, Length(Decoded));
      if Length(ImgBytes) > 0 then
        Move(Decoded[1], ImgBytes[0], Length(Decoded));
      ImgStream := TFileStream.Create(ImgName, fmCreate);
      try
        if Length(ImgBytes) > 0 then
          ImgStream.WriteBuffer(ImgBytes[0], Length(ImgBytes));
      finally
        ImgStream.Free;
      end;
    except
      // ignore
    end;
  except
    // ignore
  end;
end;

end.
