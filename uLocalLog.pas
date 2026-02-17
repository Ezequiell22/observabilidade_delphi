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
  Winapi.Windows,
  System.DateUtils,
  EncdDecd;

{ -------------------------------------------------------------------- }

class function TLocalLogHelper.LogsDir: string;
var
  Buf: array[0..MAX_PATH] of Char;
  Dir: string;
begin
  GetModuleFileName(0, Buf, MAX_PATH);
  Dir := ExtractFilePath(Buf);
  Result := IncludeTrailingPathDelimiter(Dir) + 'logs';
end;

{ -------------------------------------------------------------------- }

class procedure TLocalLogHelper.EnsureLogsDir;
begin
  if not DirectoryExists(LogsDir) then
  begin
    try
      ForceDirectories(LogsDir);
    except
      // ignore
    end;
  end;
end;

{ -------------------------------------------------------------------- }

class procedure TLocalLogHelper.PurgeOldLogs(Days: Integer);
var
  SR: TSearchRec;
  Path: string;
  NowDT, FileDT: TDateTime;
  FullName: string;
begin
  try
    Path := IncludeTrailingPathDelimiter(LogsDir) + '*.*';
    NowDT := Now;

    if System.SysUtils.FindFirst(Path, faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Attr and faDirectory) = 0 then
          begin
            FileDT := FileDateToDateTime(SR.Time);
            if DaysBetween(NowDT, FileDT) > Days then
            begin
              FullName := IncludeTrailingPathDelimiter(LogsDir) + SR.Name;
              try
                System.SysUtils.DeleteFile(FullName);
              except
                // ignore
              end;
            end;
          end;
        until System.SysUtils.FindNext(SR) <> 0;
      finally
        System.SysUtils.FindClose(SR);
      end;
    end;
  except
    // ignore
  end;
end;

{ -------------------------------------------------------------------- }

class procedure TLocalLogHelper.SaveExceptionFiles(const Item: TLogItem);
var
  BaseName, TxtName, ImgName: string;
  SL: TStringList;
  B64: string;
  ImgStream: TFileStream;
  InputStream, OutputStream: TStringStream;
begin
  try
    EnsureLogsDir;

    BaseName :=
      FormatDateTime('yyyymmdd_hhnnss', Now) + '_' +
      StringReplace(Item.ExceptionClass, ' ', '_', [rfReplaceAll]);

    TxtName := IncludeTrailingPathDelimiter(LogsDir) + BaseName + '.txt';
    ImgName := IncludeTrailingPathDelimiter(LogsDir) + BaseName + '.jpg';

    { ----------- TXT ----------- }

    SL := TStringList.Create;
    try
      SL.Add('Data/Hora: ' + DateTimeToStr(Item.TimestampUTC));
      SL.Add('Host: ' + Item.MachineName + '  Usuario: ' + Item.UserName);
      SL.Add('ERP: ' + Item.ERPVersion + '  Modulo: ' + Item.ModuleName);
      SL.Add('Classe: ' + Item.ExceptionClass);
      SL.Add('Mensagem: ' + Item.FullMessage);
      SL.Add('');
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

    { ----------- JPG (Base64) ----------- }

    B64 := Item.ScreenshotBase64;

    if B64 <> '' then
    begin
      InputStream := TStringStream.Create(B64);
      try
        OutputStream := TStringStream.Create('');
        try
          // Delphi XE2 usa DecodeStream
          DecodeStream(InputStream, OutputStream);

          if OutputStream.Size > 0 then
          begin
            ImgStream := TFileStream.Create(ImgName, fmCreate);
            try
              OutputStream.Position := 0;
              ImgStream.CopyFrom(OutputStream, OutputStream.Size);
            finally
              ImgStream.Free;
            end;
          end;
        finally
          OutputStream.Free;
        end;
      finally
        InputStream.Free;
      end;
    end;

  except
    // nunca levanta
  end;
end;

end.

