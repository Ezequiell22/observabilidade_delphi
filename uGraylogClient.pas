unit uGraylogClient;
{
  Cliente Graylog compatível com GELF 1.1.
  - Suporta UDP (com compressão zlib) e TCP (terminado por #0).
  - Timeouts curtos para não bloquear UI.
  - SendJSON recebe JSON já no formato GELF.
}

interface

uses
  System.SysUtils, System.Classes, IdUDPClient, IdTCPClient, IdGlobal, uLogTypes;

type
  TGraylogClient = class
  private
    FHost: string;
    FPort: Integer;
    FProtocol: TTransportProtocol;
    FUDP: TIdUDPClient;
    FTCP: TIdTCPClient;
    FConnectTimeoutMs: Integer;
    FSendTimeoutMs: Integer;
    function CompressZlib(const AData: TIdBytes): TIdBytes;
  public
    constructor Create(const AHost: string; APort: Integer; AProtocol: TTransportProtocol); overload;
    destructor Destroy; override;
    procedure ConfigureTimeouts(ConnectTimeoutMs, SendTimeoutMs: Integer);
    function SendJSON(const AJson: string): Boolean;
    property Host: string read FHost;
    property Port: Integer read FPort;
    property Protocol: TTransportProtocol read FProtocol;
  end;

implementation

uses
  System.ZLib, Winapi.Windows;

constructor TGraylogClient.Create(const AHost: string; APort: Integer; AProtocol: TTransportProtocol);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FProtocol := AProtocol;
  FConnectTimeoutMs := 500;
  FSendTimeoutMs := 500;
  if FProtocol = tpUDP then
  begin
    FUDP := TIdUDPClient.Create(nil);
    FUDP.Host := FHost;
    FUDP.Port := FPort;
  end
  else
  begin
    FTCP := TIdTCPClient.Create(nil);
    FTCP.Host := FHost;
    FTCP.Port := FPort;
    FTCP.ReadTimeout := FSendTimeoutMs;
    FTCP.ConnectTimeout := FConnectTimeoutMs;
  end;
end;

destructor TGraylogClient.Destroy;
begin
  FreeAndNil(FUDP);
  FreeAndNil(FTCP);
  inherited;
end;

procedure TGraylogClient.ConfigureTimeouts(ConnectTimeoutMs, SendTimeoutMs: Integer);
begin
  FConnectTimeoutMs := ConnectTimeoutMs;
  FSendTimeoutMs := SendTimeoutMs;
  if Assigned(FTCP) then
  begin
    FTCP.ReadTimeout := FSendTimeoutMs;
    FTCP.ConnectTimeout := FConnectTimeoutMs;
  end;
end;

function TGraylogClient.CompressZlib(const AData: TIdBytes): TIdBytes;
var
  InStream, OutStream: TMemoryStream;
  Z: TZCompressionStream;
begin
  InStream := TMemoryStream.Create;
  OutStream := TMemoryStream.Create;
  try
    InStream.WriteBuffer(AData[0], Length(AData));
    InStream.Position := 0;
    Z := TZCompressionStream.Create(clMax, OutStream);
    try
      Z.CopyFrom(InStream, InStream.Size);
    finally
      Z.Free;
    end;
    SetLength(Result, OutStream.Size);
    if OutStream.Size > 0 then
    begin
      OutStream.Position := 0;
      OutStream.ReadBuffer(Result[0], OutStream.Size);
    end;
  finally
    InStream.Free;
    OutStream.Free;
  end;
end;

function TGraylogClient.SendJSON(const AJson: string): Boolean;
var
  Data, Compressed: TIdBytes;
  NullByte: TIdBytes;
begin
  Result := False;
  try
    Data := ToBytes(AJson, IndyTextEncoding_UTF8);
    if FProtocol = tpUDP then
    begin

      if Assigned(FUDP) then
        FUDP.SendBuffer(data);
      Result := True;
    end
    else
    begin
      if not FTCP.Connected then
        FTCP.ConnectTimeout := FConnectTimeoutMs;
      if not FTCP.Connected then
        FTCP.Connect;
      FTCP.IOHandler.Write(Data);
      SetLength(NullByte, 1);
      NullByte[0] := 0;
      FTCP.IOHandler.Write(NullByte);
      Result := True;
    end;
  except
    on E: Exception do
    begin
      Result := False;
    end;
  end;
end;

end.
