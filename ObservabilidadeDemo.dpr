program ObservabilidadeDemo;

uses
  Vcl.Forms,
  System.SysUtils,
  uExceptionLogger in 'uExceptionLogger.pas',
  uGraylogClient in 'uGraylogClient.pas',
  uLocalLog in 'uLocalLog.pas',
  uLogDispatcher in 'uLogDispatcher.pas',
  uLogTypes in 'uLogTypes.pas',
  uScreenshotHelper in 'uScreenshotHelper.pas',
  uStackTraceHelper in 'uStackTraceHelper.pas';

{$R *.res}

begin
  Application.Initialize;

  TExceptionLogger.Initialize(
      '192.168.0.2',
       12201,
      '1.0.0',
      'Empresa Demonstração',
      'Filial 01',
      tpUDP
    );

  TExceptionLogger.LogMessage(llInfo, 'Aplicação iniciada', 'Demonstração de logging para Graylog');
  try
    // Exemplo: forçar uma exceção para testar captura automática
    raise Exception.Create('Falha de teste para validar envio GELFi');
  except
    on E: Exception do
    begin
      Application.HandleException(E);
    end;
  end;
  Application.Run;
  TExceptionLogger.FinalizeLogger;
end.
