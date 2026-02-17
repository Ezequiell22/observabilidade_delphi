program ObservabilidadeDemo;

uses
  Vcl.Forms,
  uExceptionLogger in 'uExceptionLogger.pas',
  uLogTypes in 'uLogTypes.pas', System.SysUtils;

{$R *.res}

begin
  Application.Initialize;

  TExceptionLogger.Initialize(
      '192.168.0.2',
      12201,
      '1.0.0',
      tpTCP
    );

  TExceptionLogger.LogMessage(llInfo, 'Aplicação iniciada', 'Demonstração de logging para Graylog');
  try
    // Exemplo: forçar uma exceção para testar captura automática
    raise Exception.Create('Falha de teste para validar envio GELF');
  except
    on E: Exception do
    begin
      Application.HandleException(E);
    end;
  end;
  Application.Run;
  TExceptionLogger.FinalizeLogger;
end.

