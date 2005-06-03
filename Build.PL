use Module::Build;
my $build = Module::Build->new (
  module_name => 'Business::Bof',
  dist_author => 'Kaare Rasmussen <kar at kakidata.dk>',
  dist_abstract => 'A Framework for Business Oriented Tasks',
  dist_version => '0.03',
  license => 'perl',
  requires => {
    'perl'                         => '5.8.3',
    'POE'                          => '0.29',
    'POE::Component::Server::SOAP' => '1.05',
    'DateTime'                     => '0.22',
    'DBD::SQLite'                  => '0',
    'DBIx::Recordset'              => '0',
    'Class::DBI'                   => 'x',
    'Log::Log4perl'                => '0.47',
    'SOAP::Lite'                   => '0.60',
    'XML::Dumper'                  => '0.71',
    'Digest::MD5'                  => '2.33',
    'Printer'                      => '0',
    'LWP::Protocol::https'         => '0'
  },
);
$build->create_build_script;
