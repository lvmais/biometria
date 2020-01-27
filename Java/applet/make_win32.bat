@echo off

rem -------------------------------------------------------------------------------
rem  GrFinger Sample
rem  (c) 2005,2006 Griaule Tecnologia Ltda.
rem  http://www.griaule.com
rem  -------------------------------------------------------------------------------
rem 
rem  This sample is provided with "GrFinger Fingerprint Recognition Library" and
rem  can't run without it. It's provided just as an example of using GrFinger
rem  Fingerprint Recognition Library and should not be used as basis for any
rem  commercial product.
rem 
rem  Griaule Tecnologia makes no representations concerning either the merchantability
rem  of this software or the suitability of this sample for any particular purpose.
rem 
rem  THIS SAMPLE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
rem  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
rem  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
rem  IN NO EVENT SHALL GRIAULE BE LIABLE FOR ANY DIRECT, INDIRECT,
rem  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
rem  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
rem  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
rem  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
rem  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
rem  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
rem 
rem  You can download the free version of GrFinger directly from Griaule website.
rem                                                                    
rem  These notices must be retained in any copies of any part of this
rem  documentation and/or sample.
rem 
rem  -------------------------------------------------------------------------------

rem This batch file compiles GrFinger Java Applet Sample
rem It will try finding all necessary files given same basic info:
rem - variable INSTALLDIR (where the required DLLs will be zipped)
rem - variable LICENSEDIR (where the license files can be found)
rem - variable DEPDLLDIR (where the required DLLs/JARs can be found)
rem - variable GRFINGERDLLDIR (where GRFINGER.DLL can be found)
rem - variable OUTPUTDIR (where the applet JAR will be created)

rem -------------------Setting Variables---------------------------------
set INSTALLDIR=InstallTemp
set LICENSEDIR=.\License
rem LICENSEDIR=%APPDATA%\Griaule
set DEPDLLDIR=..\..\..\bin
set PLUGINDLLDIR=..\..\..\bin
set GRFINGERDLLDIR=%DEPDLLDIR%
set OUTPUTDIR=.
rem ---------------------------------------------------------------------

rem ------------------Creating package-----------------------------------
:CHECKF
echo ----Checking if required files exist
if not exist "%GRFINGERDLLDIR%\GrFinger.dll" goto GRFINGERDLLNOTFOUND
if not exist "..\..\..\GrFingerLicenseAgreementLightTrial.txt" goto LICUSER
set LICENSEDIR=..\..\..
:LICUSER
if not exist "%LICENSEDIR%\GrFingerLicenseAgreementLightTrial.txt" goto LICNFOUND	

if not exist "%INSTALLDIR%" mkdir "%INSTALLDIR%"
del /q /s "%INSTALLDIR%\*.*"

echo ----Zipping the required DLLs
if not exist "%INSTALLDIR%\dll" mkdir "%INSTALLDIR%\dll"
del /q /s "%INSTALLDIR%\dll\*.*"
copy /b /y "%DEPDLLDIR%\*.dll" "%INSTALLDIR%\dll"
rem copy /b /y "%PLUGINDLLDIR%\CapPlugin*.dll" "%INSTALLDIR%\dll"

if exist "%INSTALLDIR%\dll\GrFingerX.dll" del /f "%INSTALLDIR%\dll\GrFingerX.dll"
"%JAVA_HOME%\bin\jar" cfM "%INSTALLDIR%\GrFingerDLLs.zip" -C "%INSTALLDIR%\dll" .
echo.

echo ----Extracting required classes to com.griaule.grFinger (discard META-INF)
"%JAVA_HOME%\bin\jar" xfM "%DEPDLLDIR%\GrFingerJava.jar" com
"%JAVA_HOME%\bin\jar" xfM "%DEPDLLDIR%\GrFingerAppletInstaller.jar" com
move com "%INSTALLDIR%"
echo.

echo ----Compiling the Java Applet
"%JAVA_HOME%\bin\javac" -source 1.4 -target 1.4 -nowarn -classpath "%INSTALLDIR%" src\com\griaule\grFingerSample\*.java -d "%INSTALLDIR%"
echo.

echo ----Creating Applet Jar File
"%JAVA_HOME%\bin\jar" cf GrFingerJavaAppletSample.jar -C "%INSTALLDIR%" com -C "%INSTALLDIR%" GrFingerDLLs.zip -C "%LICENSEDIR%" GrFingerLicenseAgreementLightTrial.txt
echo.

echo ----Creating Temporary RSA Key
if not exist ..\..\..\..\..\..\cert\java goto GENKS
copy /b /y ..\..\..\..\..\..\cert\java\java.keystore GrTmpRSAKey
goto SIGNJAR
:GENKS
"%JAVA_HOME%\bin\keytool" -genkey -alias applet -keystore GrTmpRSAKey -keypass secret -dname "cn=GrFinger Sample Applet" -storepass secret

:SIGNJAR
echo.
echo ----Signing the applet JAR (KeyStore Password: "secret")
if not exist "%OUTPUTDIR%" mkdir "%OUTPUTDIR%"
"%JAVA_HOME%\bin\jarsigner" -keystore GrTmpRSAKey -signedjar "%OUTPUTDIR%\SignedGrFingerJavaAppletSample.jar" GrFingerJavaAppletSample.jar applet
echo.

echo ----Removing temporary files
del /q GrTmpRSAKey
del /q GrFingerJavaAppletSample.jar
rmdir /s /q "%INSTALLDIR%"
echo.
goto END

:GRFINGERDLLNOTFOUND
echo GrFinger.dll not found in directory "%GRFINGERDLLDIR%"
goto END

:LICNFOUND
echo License files not found in directory "%LICENSEDIR%"
goto END

:END
echo.
@echo on