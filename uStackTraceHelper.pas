unit uStackTraceHelper;

interface

uses
  System.SysUtils;

type
  TStackTraceHelper = class
  public
    class procedure Initialize;
    class function CaptureExceptionStack(const E: Exception): string;
  end;

implementation

uses
  JclDebug, System.Classes;

class procedure TStackTraceHelper.Initialize;
begin
  try
    JclStartExceptionTracking;
  except
    // ignore
  end;
end;

class function TStackTraceHelper.CaptureExceptionStack(const E: Exception): string;
var
  SL: TStringList;
begin
  Result := '';
  SL := TStringList.Create;
  try
    try
      if Assigned(E) then
      begin
        JclLastExceptStackListToStrings(SL, True, True, True, True);
        Result := SL.Text;
      end;
    except
      // ignore
    end;
  finally
    SL.Free;
  end;
end;

end.
