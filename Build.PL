use Module::Build;
my $build = Module::Build->new (
  module_name => 'Business::Bof',
  dist_version => '0.01',
  license => 'perl',
  requires => {
    'perl'                         => '5.8.3',
    'POE'                          => '0.29',
    'POE::Component::Server::SOAP' => '1.05',
    'DateTime'                     => '0.22',
    'DBIx::Recordset'              => '0.25',
    'Log::Log4perl'                => '0.47',
    'SOAP::Lite'                   => '0.60',
    'XML::Dumper'                  => '0.71',
    'Digest::MD5'                  => '2.33',
    'PDF::Report'                  => '1.20'
  },
);
$build->create_build_script;
