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
		my $list = join('\n', @_);
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

sub getOpenSSL
{
	my ($config) = @_;
	unless (-f "$config->{workindCopyDir}/.git/HEAD" )
	{
		executeShell("git clone -b $config->{gitBranch} $config->{gitRepository} $config->{workindCopyDir}");
	}
	chdir($config->{workindCopyDir});
	executeShell("git pull origin $config->{gitBranch}");
	executeShell("git checkout");
	chdir($config->{rootDir});
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

sub configureOpenSSL
{
	my ($options) = @_;
	my $config = {};
	$config->{rootDir} = $options->{workingDir};
	$config->{workindCopyDir} = "$options->{workingDir}/openssl";
	$config->{gitRepository} = 'https://github.com/openssl/openssl.git';
	$config->{gitBranch} = 'OpenSSL_1_0_2-stable';
	$config->{platform} = $options->{platform};
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
}

sub getQtBase
{
}

sub buildQtBase
{
}

my $options = getOptions();
my $opensslConfig = configureOpenSSL($options);
getOpenSSL($opensslConfig);
buildOpenSSL($opensslConfig);
my $qtbaseConfig = configureOpenSSL($options);
getQtBase($qtbaseConfig);
buildOpenSSL($qtbaseConfig);
