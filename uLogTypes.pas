unit uLogTypes;
{
  Tipos base para o sistema de logging.
  - TLogLevel: níveis compatíveis com syslog.
  - TTransportProtocol: escolha entre UDP e TCP (GELF).
  - TLogItem: payload interno com metadados (user, machine, ERP, módulo).
  Inclui conversão de nível para código syslog exigido pelo Graylog.
}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

  TTransportProtocol = (tpUDP, tpTCP);

  TLogItem = class
  public
    TimestampUTC: TDateTime;
    Level: TLogLevel;
    ShortMessage: string;
    FullMessage: string;
    ExceptionClass: string;
    StackTrace: string;
    ScreenshotBase64: string;
    UserName: string;
    MachineName: string;
    ERPVersion: string;
    ModuleName: string;
    CompanyName: string;
    BranchId: string;
    Additional: TDictionary<string, string>;
    constructor Create;
    destructor Destroy; override;
  end;

function LogLevelToSyslog(const Level: TLogLevel): Integer;

implementation

uses
  Winapi.Windows;

constructor TLogItem.Create;
begin
  inherited Create;
  TimestampUTC := Now;
  Level := llInfo;
  Additional := TDictionary<string, string>.Create;
end;

destructor TLogItem.Destroy;
begin
  Additional.Free;
  inherited;
end;

function LogLevelToSyslog(const Level: TLogLevel): Integer;
begin
  case Level of
    llDebug: Result := 7;
    llInfo:  Result := 6;
    llWarn:  Result := 4;
    llError: Result := 3;
    llFatal: Result := 2;
  else
    Result := 6;
  end;
end;

end.

