program DemoBiometriaPV;

uses
  Forms,
  uDemoPV in 'uDemoPV.pas' {formBiometria},
  GrFinger in '..\GrFinger.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Biometria';
  Application.CreateForm(TformBiometria, formBiometria);
  Application.Run;
end.
