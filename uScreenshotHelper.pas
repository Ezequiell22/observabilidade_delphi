unit uScreenshotHelper;
{
  Captura screenshot do desktop (área virtual) no momento do erro.
  - Usa BitBlt para copiar o DC da tela para TBitmap.
  - Converte para JPEG com qualidade ajustável.
  - Codifica em Base64 para anexar no GELF.
  - Aplica limite de tamanho para evitar payload excessivo.
}

interface

uses
  System.SysUtils;

type
  TScreenshotHelper = class
  public
    class function CaptureScreenToBase64JPEG(Quality: Integer = 60; MaxBytes: Integer = 512 * 1024): string;
  end;

implementation

uses
  Winapi.Windows, Vcl.Graphics, Vcl.Imaging.jpeg, System.Classes, EncdDecd;

class function TScreenshotHelper.CaptureScreenToBase64JPEG(Quality: Integer; MaxBytes: Integer): string;
var
  bmp: TBitmap;
  jpg: TJPEGImage;
  ms: TMemoryStream;
  dc: HDC;
  w, h, x, y: Integer;
begin
  Result := '';
  bmp := TBitmap.Create;
  jpg := TJPEGImage.Create;
  ms := TMemoryStream.Create;
  try
    x := GetSystemMetrics(SM_XVIRTUALSCREEN);
    y := GetSystemMetrics(SM_YVIRTUALSCREEN);
    w := GetSystemMetrics(SM_CXVIRTUALSCREEN);
    h := GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (w <= 0) or (h <= 0) then Exit;
    bmp.PixelFormat := pf24bit;
    bmp.Width := w;
    bmp.Height := h;
    dc := GetDC(0);
    try
      BitBlt(bmp.Canvas.Handle, 0, 0, w, h, dc, x, y, SRCCOPY);
    finally
      ReleaseDC(0, dc);
    end;
    jpg.Assign(bmp);
    jpg.CompressionQuality := Quality;
    jpg.Compress;
    jpg.SaveToStream(ms);
    if ms.Size > MaxBytes then
      Exit;
    ms.Position := 0;
    Result := EncodeBase64(ms.Memory^, ms.Size);
  except
    on E: Exception do
      Result := '';
  end;
  ms.Free;
  jpg.Free;
  bmp.Free;
end;

end.
