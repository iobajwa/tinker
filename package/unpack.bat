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

echo removing .rspec
rmdir /s /q "%base_path%\.rspec"

echo removing Gemfile
rmdir /s /q "%base_path%\Gemfile"

echo removing Gemfile.lock
rmdir /s /q "%base_path%\Gemfile.lock"

echo copying "%base_path%/lib" to "%base_path%"
xcopy /s "%base_path%/lib" "%base_path%"
