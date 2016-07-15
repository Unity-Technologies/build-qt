use warnings;
use strict;
use Getopt::Long;
use Params::Check;
use Cwd;

sub executeShell
{
	my $commands = join(' && ', @_);
	my $code = system($commands);
	if ($code != 0)
	{
		my $list = join("\n", @_);
		die("FAIL: Error $code. Failed to execute commands:\n$list\n");
	}
}

sub getOptions
{
	my $options = {
		workingDir => Cwd::getcwd()
	};
	my $scheme = {
		platform => { required => 1, allow => ['win32', 'win64'] }
	};
	Getopt::Long::GetOptions('platform=s' => \$options->{platform});
	Params::Check::check($scheme, $options, 0) or die("Wrong arguments");
	return $options;
}

sub getSources
{
	my ($config) = @_;
	unless (-f "$config->{workindCopyDir}/.git/HEAD" )
	{
		executeShell("git clone -b $config->{gitBranch} $config->{gitRepository} $config->{workindCopyDir}");
	}
	chdir($config->{workindCopyDir});
	executeShell("git pull origin $config->{gitBranch}");
	executeShell("git checkout $config->{gitBranch}");
	chdir($config->{rootDir});
}

sub getOpenSSL
{
	return getSources(@_);
}

sub buildOpenSSL
{
	my ($config) = @_;
	chdir($config->{workindCopyDir});
	executeShell(
			"\"C:/Program Files (x86)/Microsoft Visual Studio 10.0/VC/vcvarsall.bat\" $config->{vcArch}",
			"perl Configure $config->{opensslArch} no-asm no-shared --prefix=$config->{targetDir}",
			$config->{msStep},
			"nmake -f .\\ms\\nt.mak",
			"nmake -f .\\ms\\nt.mak test",
			"nmake -f .\\ms\\nt.mak install");
	chdir($config->{rootDir});
}

sub basicConfiguration
{
	my ($options) = @_;
	my $config = {};
	$config->{platform} = $options->{platform};
	$config->{rootDir} = $options->{workingDir};
	return $config;
}

sub configureOpenSSL
{
	my ($options) = @_;
	my $config = basicConfiguration($options);
	$config->{workindCopyDir} = "$options->{workingDir}/openssl";
	$config->{gitRepository} = 'https://github.com/openssl/openssl.git';
	$config->{gitBranch} = 'OpenSSL_1_0_2-stable';
	if ($options->{platform} eq 'win32')
	{
		$config->{vcArch} = 'x86';
		$config->{opensslArch} = 'VC-WIN32';
		$config->{msStep} = '.\\ms\\do_ms.bat';
	}
	elsif ($options->{platform} eq 'win64')
	{
		$config->{vcArch} = 'amd64';
		$config->{opensslArch} = 'VC-WIN64A';
		$config->{msStep} = '.\\ms\\do_win64a.bat';
	}
	$config->{targetDir} = "$options->{workingDir}/build/$options->{platform}/openssl";
	return $config;
}

sub configureQtBase
{
	my ($options) = @_;
	my $config = basicConfiguration($options);
	$config->{workindCopyDir} = "$options->{workingDir}/qtbase";
	$config->{gitRepository} = 'https://code.qt.io/qt/qtbase.git';
	$config->{gitBranch} = '5.3.2';
	if ($options->{platform} eq 'win32')
	{
		$config->{vcArch} = 'x86';
		$config->{qtArch} = 'win32-msvc2010';
	}
	elsif ($options->{platform} eq 'win64')
	{
		$config->{vcArch} = 'amd64';
		$config->{qtArch} = 'win32-msvc2010';
	}
	$config->{targetDir} = "$options->{workingDir}/build/$options->{platform}/qtbase";
	$config->{opensslDir} = $options->{opensslDir};
	return $config;
}

sub getQtBase
{
	my ($config) = @_;
	return getSources($config);
}

sub buildQtBase
{
	my ($config) = @_;
	chdir($config->{workindCopyDir});
	$ENV{_ROOT} = $config->{workindCopyDir};
	$ENV{PATH} = "$ENV{_ROOT}\\qtbase\\bin;$ENV{_ROOT}\\gnuwin32\\bin;$ENV{PATH}";
	$ENV{QMAKESPEC} = $config->{qtArch};
	executeShell(
			"\"C:/Program Files (x86)/Microsoft Visual Studio 10.0/VC/vcvarsall.bat\" $config->{vcArch}",
			"configure -prefix $config->{targetDir} -opensource -confirm-license -no-opengl -no-icu -no-rtti -no-dbus -strip -nomake examples -nomake tests -openssl-linked OPENSSL_LIBS=\"-lssleay32 -llibeay32 -lgdi32 -luser32\" -I \"$config->{opensslDir}/include\" -L \"$config->{opensslDir}/lib\"",
			"nmake install"
			);
	chdir($config->{rootDir});
}

my $options = getOptions();

my $opensslConfig = configureOpenSSL($options);
getOpenSSL($opensslConfig);
buildOpenSSL($opensslConfig);
$options->{opensslDir} = $opensslConfig->{targetDir};

my $qtbaseConfig = configureQtBase($options);
getQtBase($qtbaseConfig);
buildQtBase($qtbaseConfig);
