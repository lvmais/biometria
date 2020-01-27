unit uDemoPV;

interface
{$D+}
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, jpeg, StdCtrls, JvExControls, JvXPCore, JvXPButtons,
  operando,
  GrFinger,
  DB, IBCustomDataSet, IBQuery, IBDatabase;

Type
  // Class TTemplate
  // Define a type to temporary storage of template
  TTemplatePV = class
    public
      // Template data.
      tpt:        PAnsiChar;
      // Template size
      size:       Integer;
      // Template ID (if retrieved from DB)
      id:         Integer;

      // Allocates space to template
      constructor Create;
      // clean-up
      destructor Destroy; override;
end;

type
  // Raw image data type.
  TRawImage = record
    // Image data.
    img:        PAnsiChar;
    // Image width.
    width:      Integer;
    // Image height.
    Height:     Integer;
    // Image resolution.
    Res:        Integer;
  end;


type
  TformBiometria = class(TForm)
    panoBiometria: TPanel;
    panoFotoBiometria: TPanel;
    Image1: TImage;
    panoDigital1: TPanel;
    panoDigital2: TPanel;
    imageDigital1: TImage;
    imageDigital2: TImage;
    imageContemDigital1: TImage;
    ImageContemDigital2: TImage;
    Label1: TLabel;
    Label2: TLabel;
    jvCaptura1: TJvXPButton;
    jvCaptura2: TJvXPButton;
    jvGravar: TJvXPButton;
    IBD: TIBDatabase;
    IBT: TIBTransaction;
    Digitais: TIBQuery;
    cod: TEdit;
    nome: TEdit;
    Label3: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure jvGravarClick(Sender: TObject);
    procedure ProcuraDigital ;
    procedure jvCaptura1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  procedure FinalizeGrFinger();
  function InitializeGrFinger(): Integer;
  function InitializeGrCap():Integer;
  Procedure StatusCallback(idSensor: Pchar; event: GRCAP_STATUS_EVENTS); stdcall;
  procedure WriteEvent(idSensor: Pchar; event: GRCAP_STATUS_EVENTS);
  procedure WriteLog(msg: String);
  Procedure FingerCallback(idSensor: Pchar; event: GRCAP_FINGER_EVENTS); stdcall;
  Procedure ImageCallback(idSensor: PChar; imageWidth: Integer; imageHeight: Integer; rawImage: PChar; res: Integer); stdcall;
  procedure PrintBiometricDisplay(biometricDisplay: boolean; context: Integer);
  function ExtractTemplate(): Integer;

var
  formBiometria: TformBiometria;
  // The last acquired image.
  raw : TRawImage;
  // The template extracted from the last acquired image.
  template: TTemplatePV;

implementation

{$R *.dfm}

procedure TformBiometria.FormActivate(Sender: TObject);
begin
   ibd.DatabaseName := ExtractFileDir(Application.ExeName) + '\bd\digitais.fdb' ;
end;

procedure TformBiometria.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    if jvGravar.Enabled then
        FinalizeGrFinger ;

//    if jvGravar.Enabled then
//        JvGravarClick(Sender);
        
end;

procedure TformBiometria.jvCaptura1Click(Sender: TObject);
var
    itResp : integer ;

begin

    // inicializamos o leitor Biométrico
    itResp := InitializeGrFinger() ;

    // verificamos se ocorreu tudo bem
    if itResp < 0 then begin
        ShowMessage( 'Não foi possível inicializar o Leitor Biométrico, verifique se está instalado ou conectado ao PC!' ) ;
        exit ;
    end;

    // habilitamos o botão
    jvCaptura1.Enabled := false ;
    jvGravar.Enabled   := true ;

end;

procedure TformBiometria.jvGravarClick(Sender: TObject);
var
  boOK       : boolean ;
  mstDigital : TMemoryStream;

begin

    boOK := true ;

    if imageContemDigital1.Picture.Graphic = nil then

        if not mensagem( 1, 'Digital ainda não foi capturada. Deseja Desligar o leitor?') then

            boOK := false ;


    if boOK then begin

        // Checamos se a imagem é valida.
        if ((template.size > 0) and (template.tpt <> nil)) then begin

            // criamos o objeto que receberá a imagem
            mstDigital := TMemoryStream.Create();

            try
                // Escreve a imagem no Memory Stream.
                mstDigital.write(template.tpt^, template.size);

                // abrimos a tabela
                ibd.Connected    := true ;

                ibt.Active       := true ;

                // tabela
                with Digitais do begin

                  sql.Clear;
                  sql.Add( 'select * from tabeladigitais where codigo=:icod' );
                  ParamByName('icod').AsString := cod.Text ;
                  active := true ;

                  if eof then begin
                    sql.Clear;
                    sql.Add( 'INSERT INTO tabeladigitais (codigo,nome,digital1) values (:iCod,:snome,:Mdigital1)' ) ;
                    ParamByName('icod').AsString := cod.Text ;
                    ParamByName('snome').AsString := nome.Text ;
                    ParamByName('mdigital1').LoadFromStream( mstDigital, ftBlob );
                    ExecSQL;
                  end else begin
                    sql.Clear;
                    sql.Add( 'UPDATE tabeladigitais set digital1 = :Mdigital1 where codigo = :iCod' ) ;
                    ParamByName('Mdigital1').LoadFromStream( mstDigital, ftBlob );
                    ParamByName('iCod').AsString := cod.Text ;
                    ExecSQL;
                    mensagem(0, 'Digital Gravada com sucesso!');
                  end;

                  ibt.CommitRetaining;

                end;

            finally

                // liberamos a imagem
                mstDigital.Free ;

            end; { Fim do TRY }

            // Desligamos o Leitor Biométrico
            FinalizeGrFinger ;
            jvGravar.Enabled   := false ;
            jvCaptura1.Enabled := true ;

        end; { If Chaca se a imagem é válida }

    end; {  If boOK  }

end;

procedure TformBiometria.ProcuraDigital ;
var
  ret      : integer ;
  dig      : string ;
  score    : integer ;
  tptBlob  : TTemplatePV;

begin

    // Checamos se a imagem é valida.
    if ((template.size > 0) and (template.tpt <> nil)) then begin

        // Iniciamos o processo de identificação do template.
        ret := GrIdentifyPrepare( template.tpt, GR_DEFAULT_CONTEXT);

        // gerou erro
        if (ret < 0) then begin
          mensagem(0, 'Gerou erro' ) ;
          exit;
        end;

        // aqui deveremos fazer um looping do arquivo
        if not ibd.Connected then ibd.Connected := true ;
        if not ibt.Active then ibt.Active := true ;

        // Criamos a template
        tptBlob := TTemplatePV.Create ;

        // iniciamos variavel
        label3.Caption := '' ;

        with Digitais do begin

            sql.Clear;
            sql.Add( 'select * from tabeladigitais where digital1 is not null' ) ;
            active := true;
            First;

            while not eof do begin

                // capturamos a digital
                dig := FieldByName('digital1').AsString ;
                // Pegamos o tamanho do template que está no banco.
                tptBlob.size := length( dig );

                Move( PansiChar( dig )^, tptBlob.tpt^, tptBlob.size);

                if tptBlob.size > 0 then begin

                    // Compara a Digital com a do Banco.
                    if GrIdentify( tptBlob.tpt, score, GR_DEFAULT_CONTEXT) = GR_MATCH then begin

                      label3.Caption := 'Achou: ' + FieldByName('nome').asstring ;
                      exit;

                    end; { fim if GrIdentify }

                end; { FIM if size > 0 }

                Next ;

            end; { fim do While EOF }

        end; { fim WITH DIGITAIS }

        // destruimos
        tptBlob.Destroy ;



    end; { fim if template }

end;





constructor TTemplatePV.Create();
begin
  // Aloca na memoria e inicializa com 0
  tpt := AllocMem(GR_MAX_SIZE_TEMPLATE);
  size := 0;
end;
// Destruir
destructor TTemplatePV.Destroy();
begin
  // Libera da memória
  FreeMemory(tpt);
end;



procedure FinalizeGrFinger();
begin
  // finalize library
  GrFinalize();
  GrCapFinalize();
  // Closing database
//  DB.closeDB();
//  DB.Free();
  // Freeing resources
  if Assigned( template ) then begin
      template.Free();
      //FreeMemory(raw.img);
      raw.img := nil ;
  end;
end;

function InitializeGrFinger(): Integer;
var
  err: Integer;
begin
  // Opening database
{  DB := TDBClass.Create();
  if not DB.openDB() then begin
    InitializeGrFinger := ERR_CANT_OPEN_BD;
    Exit;
  end;

}  // Create a new Template
    template := TTemplatePV.Create();

  // Create a new raw image
  if raw.img = nil then
    raw.img := AllocMem(GR_MAX_IMAGE_HEIGHT * GR_MAX_IMAGE_WIDTH);
  // Initializing library.
  err := GrInitialize();

  if (err < 0) then begin
    InitializeGrFinger := err;
    exit;
  end;

  InitializeGrFinger := InitializeGrCap();

end;


// Initialize capture library
function InitializeGrCap():Integer;
begin
  // Initializing GrCapture. Passing adress of the "StatusCallback" sub.
  InitializeGrCap := GrCapInitialize(@StatusCallback);
end;

// This sub is called evertime an status event is raised.
Procedure StatusCallback(idSensor: Pchar; event: GRCAP_STATUS_EVENTS); stdcall;
begin
  // Signals that a status event ocurred.
//  WriteEvent(idSensor, event);
  // Checking if event raised is a plug or unplug.
  if (event = GR_PLUG) then
    // Start capturing from plugged sensor.
    GrCapStartCapture(idSensor, @FingerCallback, @ImageCallback)
  else if (event = GR_UNPLUG) then
    // Stop capturing from unplugged sensor.
    GrCapStopCapture(idSensor);
end;

// Change Event codes into friendly messagens
procedure WriteEvent(idSensor: Pchar; event: GRCAP_STATUS_EVENTS);
begin
  case event of
    GR_PLUG: WriteLog('Sensor: '+idSensor+'. Event: Plugged.');
    GR_UNPLUG: WriteLog('Sensor: '+idSensor+'. Event: Unplugged.');
    GR_FINGER_DOWN: WriteLog('Sensor: '+idSensor+'. Event: Finger Placed.');
    GR_FINGER_UP: WriteLog('Sensor: '+idSensor+'. Event: Finger Removed.');
    GR_IMAGE: WriteLog('Sensor: '+idSensor+'. Event: Image Captured.');
  else
    WriteLog('Sensor: '+idSensor+'. Event:('+IntToStr(event)+')');
  end;
end;
procedure WriteLog(msg: String);
Begin
  // add message
//  formMain.memoLog.Lines.Add(msg);
end;
// This Function is called every time a finger is placed or removed from sensor.
Procedure FingerCallback(idSensor: Pchar; event: GRCAP_FINGER_EVENTS); stdcall;
Begin
  // Just signals that a finger event ocurred.
  WriteEvent(idSensor, event);
End;
// This function is called every time a finger image is captured
Procedure ImageCallback(idSensor: PChar; imageWidth: Integer; imageHeight: Integer; rawImage: PChar; res: Integer); stdcall;
Begin
  // Copying aquired image
  raw.height := imageHeight;
  raw.width := imageWidth;
  raw.res := res;
  Move(rawImage^, raw.img^, imageWidth*imageHeight);

  // Signaling that an Image Event occurred.
  WriteEvent(idSensor, GR_IMAGE);

  // Colocamos a imagem no Display
  PrintBiometricDisplay(false, GR_DEFAULT_CONTEXT);

  // Ligamos a identificação da Biometria
  ExtractTemplate();
  PrintBiometricDisplay(true, GR_NO_CONTEXT);

  // identificamos caso exista.....
  formBiometria.ProcuraDigital ;


end;

// Display fingerprint image on screen
procedure PrintBiometricDisplay(biometricDisplay: boolean; context: Integer);
var
  // handle to finger image
  handle: HBitmap;
  // screen HDC
  hdc: LongInt;
begin


  // free previous image
//  formMain.image.Picture.Bitmap.FreeImage();
//  handle := formMain.image.Picture.Bitmap.ReleaseHandle();
  DeleteObject(handle);

  {If range checking is on - turn it off for now
   we will remember if range checking was on by defining
   a define called CKRANGE if range checking is on.
   We do this to access array members past the arrays
   defined index range without causing a range check
   error at runtime. To satisfy the compiler, we must
   also access the indexes with a variable. ie: if we
   have an array defined as a: array[0..0] of byte,
   and an integer i, we can now access a[3] by setting
   i := 3; and then accessing a[i] without error}
  {$IFOPT R+}
    {$DEFINE CKRANGE}
  {$R-}
  {$ENDIF}
   // get screen HDC
  hdc := GetDC(HWND(nil));

  if biometricDisplay then
    // get image with biometric info
    GrBiometricDisplay(template.tpt,raw.img, raw.width, raw.height,raw.Res, hdc,
                        handle, context)
  else
    // get raw image
    GrCapRawImageToHandle(raw.img, raw.width, raw.height, hdc, handle);

  // draw image on picture box
  if handle <> 0 then
  begin

      with formBiometria.imageContemDigital1 do begin

          Picture.Bitmap.Handle := handle;
          Repaint;

      end;

   end;

  // release screen HDC
  ReleaseDC(HWND(nil), hdc);

  {Turn range checking back on if it was on when we started}
  {$IFDEF CKRANGE}
    {$UNDEF CKRANGE}
    {$R+}
  {$ENDIF}
end;
function ExtractTemplate(): Integer;
Var
  ret: Integer;
Begin
  // set current buffer size for extract template
  template.size := GR_MAX_SIZE_TEMPLATE;
  ret := GrExtract(raw.img, raw.width, raw.height, raw.res, template.tpt,
                        template.size, GR_DEFAULT_CONTEXT);
  // if error, set template size to 0
  // Result < 0 => extraction problem
  if (ret < 0 ) then
    template.size := 0;
  ExtractTemplate := ret;
End;







end.
