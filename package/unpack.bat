@echo off
	rem The package folder can be downloaded anywhere (inside a temp folder)
	rem usually it's the ArtifactsRoot\packages\tinker folder.
	rem Once the package has been downloaded, this file should be run. This
	rem file (unpack.bat) automatically installs the package.

	rem assumes argument to CD is passed as arg1 to this file (where the package
	rem has been downloaded)

set base_path=%~1
echo path provided '%base_path%'

echo copying "%base_path%/content" to "%base_path%"
xcopy /s "%base_path%/content" "%base_path%"

echo removing directory "%base_path%\content"
rmdir /s /q "%base_path%\content"

echo removing directory "%base_path%\spec"
rmdir /s /q "%base_path%\spec"

echo deleting .rspec
del "%base_path%\.rspec"

echo deleting "%base_path%\Gemfile"
del "%base_path%\Gemfile"

echo deleting Gemfile.lock
del "%base_path%\Gemfile.lock"

echo copying "%base_path%/lib" to "%base_path%"
xcopy /s "%base_path%/lib" "%base_path%"

echo removing directory "%base_path%/lib"
rmdir /s /q "%base_path%/lib"

	rem create the load_script
set env_load_script="%base_path%\env.txt"
echo creating environment script '%env_load_script%'
echo %base_path% > %env_load_script%

echo done.