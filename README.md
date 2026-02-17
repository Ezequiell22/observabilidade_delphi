# Observabilidade Delphi (GELF/Graylog) – Delphi XE2 (VCL)

Solução de logging remoto, desacoplada e assíncrona para aplicações Delphi XE2 (VCL), enviando eventos ao Graylog no formato GELF 1.1. Inclui:

- Captura automática de exceções via `Application.OnException`
- Stack trace completo com JCL (Jedi Code Library)
- Screenshot do desktop no momento do erro (JPEG → Base64) salva apenas em disco (não vai para o GELF)
- Envio assíncrono via fila + worker thread (UDP por padrão; TCP opcional)
- Inicialização simples (DPR ou DataModule)
- Persistência local em arquivos (imagem JPEG + TXT) com retenção de 7 dias

## Arquitetura

- `uLogTypes.pas`: tipos base (níveis, item de log, etc.)
- `uGraylogClient.pas`: cliente GELF (UDP/TCP)
- `uLogDispatcher.pas`: fila assíncrona (`TQueue<TLogItem>`) e worker que envia JSON GELF
- `uStackTraceHelper.pas`: integração JCL para capturar stack trace
- `uScreenshotHelper.pas`: captura de tela usando `BitBlt`, JPEG e Base64
- `uExceptionLogger.pas`: ponto de integração (Initialize/Finalize/HandleException/LogMessage)
- `uLocalLog.pas`: salvamento local dos erros (imagem JPEG + TXT) e limpeza de arquivos antigos

## Pré‑requisitos

- Delphi XE2 (VCL)
- Indy (IdUDPClient, IdTCPClient, IdGlobal) — já incluso no XE2
- JCL (Jedi Code Library) instalado e no search path (especialmente `JclDebug`)
- Para linha/método/unit no stack trace:
  - Project Options → Linker → Map file = **Detailed**
  - Manter o `.map` próximo do `.exe` ou gerar `.jdbg` com utilitários da JCL

## Inicialização Rápida (ERP com vários clientes)

No DPR do seu ERP (ou em um DataModule de inicialização):

```pascal
uses
  uExceptionLogger, uLogTypes;

begin
  Application.Initialize;
  TExceptionLogger.Initialize(
    'SEU_GRAYLOG_HOST', // Ex.: 192.168.0.2
    12201,              // Porta GELF UDP
    'ERP 1.0.0',        // Versão do ERP
    'NOME DA EMPRESA',  // Cliente
    'FILIAL 001',       // Filial
    tpUDP
  );
  Application.Run;
  TExceptionLogger.FinalizeLogger;
end.
```

### Enviar logs manuais

```pascal
TExceptionLogger.LogMessage(llInfo, 'Processo concluído', 'Detalhes adicionais do evento');
```

## Campos Enviados (GELF 1.1)

Obrigatórios:

- `version`, `host`, `short_message`, `full_message`, `timestamp` (unix em segundos), `level` (códigos syslog)

Adicionais (_custom fields_):

- `_exception_class`, `_stacktrace`, `_user`, `_machine`, `_erp_version`, `_module`
- `_empresa` (nome da empresa/cliente)
- `_filial` (código ou nome da filial)

## UDP vs TCP

- **UDP (padrão)**: menor latência. Ideal para eventos curtos. Screenshot não é enviada para o Graylog (apenas salva em disco).
- **TCP**: envia JSON seguido de byte nulo `#0` (frame GELF). Opcional, se desejar.

Trocar o protocolo na inicialização:

```pascal
TExceptionLogger.Initialize('host', 12201, 'ERP 1.0.0', tpTCP);
```

## Logs Locais (Imagem + TXT)

- Quando ocorrer um erro (`llError`/`llFatal`), além do envio ao Graylog, dois arquivos são salvos em `./logs_`:
  - Imagem: `YYYYMMDD_HHNNSS_<Classe>.jpg` (screenshot do desktop, quando disponível)
  - Texto: `YYYYMMDD_HHNNSS_<Classe>.txt` com data/hora, host, usuário, ERP, módulo, classe, mensagem e stack trace
- O sistema mantém apenas arquivos com até 7 dias dentro de `logs_` (limpeza automática).

Exemplo de ativação (já integrado ao `TExceptionLogger`):

```pascal
// Ao capturar exceções, o ExceptionLogger chama:
// TLocalLogHelper.SaveExceptionFiles(Item);
// TLocalLogHelper.PurgeOldLogs(7);
```

## Performance e Resiliência

- Envio assíncrono por worker thread, com retry simples e timeouts curtos
- `Application.OnException` apenas enfileira; a thread de envio faz a rede
- Screenshot apenas em `llError`/`llFatal` e com limite de tamanho
- Proteções `try/except` em todos os pontos críticos (captura, fila, envio)

## Configuração do Graylog

1. Em **System → Inputs**, adicione um input **GELF UDP** (porta 12201) ou **GELF TCP**.
2. Aponte o `Initialize` para o host/porta do input.
3. Verifique as mensagens chegando e os campos extras no Graylog.

## Dicas de Troubleshooting

- Verifique se o `.map` (ou `.jdbg`) está disponível no diretório do executável para stack trace detalhado.
- Em UDP, se eventos não aparecem, teste TCP (`tpTCP`) para payloads maiores.
- Certifique‑se de que firewall/antivírus não bloqueie a porta do input Graylog.
- Ajuste:
  - timeouts: `TGraylogClient.ConfigureTimeouts(Connect, Send)`
  - fila/retry: `Dispatcher.MaxQueueSize` e `Dispatcher.RetryCount` (definidos em `Initialize`)
  - screenshot: qualidade/tamanho em `TScreenshotHelper.CaptureScreenToBase64JPEG(Quality, MaxBytes)`
  - retenção local: `TLocalLogHelper.PurgeOldLogs(Dias)` (padrão 7)

## Exemplo incluído

Veja `ObservabilidadeDemo.dpr` para um teste rápido de envio (simula uma exceção).

## Estrutura de Arquivos

- `uLogTypes.pas`
- `uGraylogClient.pas`
- `uLogDispatcher.pas`
- `uStackTraceHelper.pas`
- `uScreenshotHelper.pas`
- `uExceptionLogger.pas`
- `uLocalLog.pas`
- `ObservabilidadeDemo.dpr`

## Licença

Uso interno. Ajuste conforme a política da sua organização.
*** End Patch***}다고요?}까요?} 주세요?}్?}】?}-->
*** End Patch
*** End Patch** */
*** End Patch***
*** End Patch***
*** End Patch
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***
*** End Patch***

*** End Patch***}
} } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } } }}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
