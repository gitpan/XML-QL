use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'XML::QL',
    'VERSION_FROM' => 'QL.pm', # finds $VERSION
	'dist' => {compress => 'gzip', suffix => 'gz'},
);
