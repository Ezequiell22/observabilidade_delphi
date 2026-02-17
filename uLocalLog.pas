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
    class procedure SaveExceptionAsPDF(const Item: TLogItem);
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
    Path := IncludeTrailingPathDelimiter(LogsDir) + '*.pdf';
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

class procedure TLocalLogHelper.SaveExceptionAsPDF(const Item: TLogItem);
var
  MSImg: TMemoryStream;
  ImgBytes: TBytes;
  PDF: TFileStream;
  Offsets: array[1..6] of Int64;
  XRefStart: Int64;
  W, H: Integer;
  PageW, PageH: Integer;
  ImgW, ImgH: Integer;
  ScaleW, ScaleH: Double;
  PosX, PosY: Integer;
  TextContent: TStringList;
  ContentStream: TStringStream;
  FileName: string;
  B64: string;
  procedure WritelnPDF(const S: AnsiString = '');
  var
    A: AnsiString;
  begin
    A := S + #10;
    PDF.WriteBuffer(A[1], Length(A));
  end;
  function IntToAnsi(I: Integer): AnsiString;
  begin
    Result := AnsiString(IntToStr(I));
  end;
  function DoubleToAnsi(D: Double): AnsiString;
  begin
    Result := AnsiString(StringReplace(FormatFloat('0.###', D), ',', '.', []));
  end;
  function BuildTextLines: TStringList;
  const
    MaxStack = 8000;
  var
    ST: string;
    Lines: TStringList;
    I: Integer;
  begin
    Lines := TStringList.Create;
    Lines.Add('Data/Hora: ' + DateTimeToStr(Item.TimestampUTC));
    Lines.Add('Host: ' + Item.MachineName + '  Usuario: ' + Item.UserName);
    Lines.Add('ERP: ' + Item.ERPVersion + '  Modulo: ' + Item.ModuleName);
    Lines.Add('Classe: ' + Item.ExceptionClass);
    Lines.Add('Mensagem: ' + Item.FullMessage);
    Lines.Add(' ');
    Lines.Add('Stack trace:');
    ST := Item.StackTrace;
    if Length(ST) > MaxStack then
      ST := Copy(ST, 1, MaxStack) + '...';
    Result := TStringList.Create;
    Result.Assign(Lines);
    Lines.Free;
    // dividir stack em linhas
    Lines := TStringList.Create;
    Lines.Text := ST;
    for I := 0 to Lines.Count - 1 do
      Result.Add(Lines[I]);
    Lines.Free;
  end;
begin
  try
    EnsureLogsDir;
    B64 := Item.ScreenshotBase64;
    MSImg := TMemoryStream.Create;
    try
      if B64 <> '' then
      try
        // decodificar Base64 para bytes JPEG
        SetLength(ImgBytes, Length(B64) * 3 div 4 + 4);
        SetLength(ImgBytes, DecodeBase64(B64[1], Length(B64), ImgBytes[0], Length(ImgBytes)));
        if Length(ImgBytes) > 0 then
        begin
          MSImg.WriteBuffer(ImgBytes[0], Length(ImgBytes));
          MSImg.Position := 0;
        end;
      except
        MSImg.Size := 0;
      end;
      // Tentar obter dimensões aproximadas da imagem JPEG
      W := 600;
      H := 400;
      if MSImg.Size >= 4 then
      try
        // leitura simples do SOFx para width/height
        var Buf: TBytes;
        SetLength(Buf, MSImg.Size);
        MSImg.Position := 0;
        MSImg.ReadBuffer(Buf[0], MSImg.Size);
        var i: Integer := 2;
        while i + 9 < Length(Buf) do
        begin
          if (Buf[i] = $FF) and ((Buf[i+1] and $F0) = $C0) then
          begin
            H := Buf[i+5] shl 8 or Buf[i+6];
            W := Buf[i+7] shl 8 or Buf[i+8];
            Break;
          end
          else
          begin
            if (Buf[i] = $FF) then
            begin
              var L := Buf[i+2] shl 8 or Buf[i+3];
              i := i + 2 + L;
            end
            else
              Inc(i);
          end;
        end;
      except
      end;
      ImgW := W;
      ImgH := H;
    finally
      // manter MSImg para escrita na imagem do PDF
    end;

    PageW := 595; // A4 retrato (72dpi)
    PageH := 842;
    ScaleW := PageW - 100;
    if ImgW > 0 then
      ScaleH := ScaleW * ImgH / ImgW
    else
      ScaleH := 0;
    PosX := 50;
    PosY := 200;
    if Trunc(ScaleH) > PageH - 250 then
    begin
      ScaleH := PageH - 250;
      if ImgH > 0 then
        ScaleW := ScaleH * ImgW / ImgH;
    end;

    FileName := IncludeTrailingPathDelimiter(LogsDir) +
      FormatDateTime('yyyymmdd_hhnnss', Now) + '_' +
      StringReplace(Item.ExceptionClass, ' ', '_', [rfReplaceAll]) + '.pdf';
    PDF := TFileStream.Create(FileName, fmCreate);
    try
      // Header
      WritelnPDF('%PDF-1.4');
      WritelnPDF('%''#');
      // 1: Catalog
      Offsets[1] := PDF.Position;
      WritelnPDF(ToId(1));
      WritelnPDF('<< /Type /Catalog /Pages 2 0 R >>');
      WritelnPDF('endobj');
      // 2: Pages
      Offsets[2] := PDF.Position;
      WritelnPDF(ToId(2));
      WritelnPDF('<< /Type /Pages /Kids [ 3 0 R ] /Count 1 >>');
      WritelnPDF('endobj');
      // 3: Page
      Offsets[3] := PDF.Position;
      WritelnPDF(ToId(3));
      WritelnPDF('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + IntToAnsi(PageW) + ' ' + IntToAnsi(PageH) + ']');
      WritelnPDF('   /Resources << /Font << /F1 4 0 R >> /XObject << /Im0 5 0 R >> >>');
      WritelnPDF('   /Contents 6 0 R >>');
      WritelnPDF('endobj');
      // 4: Font
      Offsets[4] := PDF.Position;
      WritelnPDF(ToId(4));
      WritelnPDF('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
      WritelnPDF('endobj');
      // 5: Image (JPEG stream)
      Offsets[5] := PDF.Position;
      WritelnPDF(ToId(5));
      if (MSImg.Size > 0) then
      begin
        WritelnPDF('<< /Type /XObject /Subtype /Image /Width ' + IntToAnsi(ImgW) +
                   ' /Height ' + IntToAnsi(ImgH) +
                   ' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode');
        WritelnPDF('   /Length ' + IntToAnsi(MSImg.Size) + ' >>');
        WritelnPDF('stream');
        MSImg.Position := 0;
        PDF.CopyFrom(MSImg, MSImg.Size);
        WritelnPDF;
        WritelnPDF('endstream');
      end
      else
      begin
        // Sem imagem: fluxo vazio
        WritelnPDF('<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length 0 >>');
        WritelnPDF('stream');
        WritelnPDF('endstream');
      end;
      WritelnPDF('endobj');
      // 6: Contents (desenha imagem e escreve texto)
      Offsets[6] := PDF.Position;
      ContentStream := TStringStream.Create('', TEncoding.ASCII);
      try
        ContentStream.WriteString('q'#10);
        if (MSImg.Size > 0) then
        begin
          ContentStream.WriteString(DoubleToAnsi(ScaleW) + ' 0 0 ' + DoubleToAnsi(ScaleH) + ' ' +
                                    IntToAnsi(PosX) + ' ' + IntToAnsi(PosY) + ' cm'#10);
          ContentStream.WriteString('/Im0 Do'#10);
        end;
        ContentStream.WriteString('Q'#10);
        // Texto
        TextContent := BuildTextLines;
        try
          ContentStream.WriteString('BT /F1 10 Tf 50 150 Td 14 TL'#10);
          var i: Integer;
          for i := 0 to TextContent.Count - 1 do
          begin
            var Line := EscapePDFParen(ReplaceInvalidPDFText(TextContent[i]));
            ContentStream.WriteString('(' + Line + ') Tj T*'#10);
          end;
          ContentStream.WriteString('ET'#10);
        finally
          TextContent.Free;
        end;
      finally
        // continue
      end;
      var ContentData: AnsiString := AnsiString(ContentStream.DataString);
      ContentStream.Free;
      WritelnPDF(ToId(6));
      WritelnPDF('<< /Length ' + IntToAnsi(Length(ContentData)) + ' >>');
      WritelnPDF('stream');
      PDF.WriteBuffer(ContentData[1], Length(ContentData));
      WritelnPDF;
      WritelnPDF('endstream');
      WritelnPDF('endobj');
      // xref
      XRefStart := PDF.Position;
      WritelnPDF('xref');
      WritelnPDF('0 7');
      WritelnPDF('0000000000 65535 f ');
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[1]]));
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[2]]));
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[3]]));
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[4]]));
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[5]]));
      WritelnPDF(Format('%.10d 00000 n ', [Offsets[6]]));
      // trailer
      WritelnPDF('trailer');
      WritelnPDF('<< /Size 7 /Root 1 0 R >>');
      WritelnPDF('startxref');
      WritelnPDF(AnsiString(IntToStr(XRefStart)));
      WritelnPDF('%%EOF');
    finally
      PDF.Free;
      MSImg.Free;
    end;
  except
    // nunca levanta
  end;
end;

end.

