

1. create a new ruby script (e.g. default_injector.rb)
2. add this following code at the top of the file:
	$LOAD_PATH.unshift(ENV['PROJECT_PATHS'].split(';')).flatten!
3. enjoy.

Step #2 basically adds every path in PROJECT_PATHS to the $LOAD_PATH. This makes sure
that ruby finds tinker and other helper libraries from installed packages.
