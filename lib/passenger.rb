module Passenger

  def apache
    package "apache2-mpm-worker", :ensure => :installed
    package "apache2-threaded-dev", :ensure => :installed
    service :apache2,
            :require => [
              package("apache2-mpm-worker"),
              package("apache2-threaded-dev")
            ]
  end

  def passenger
    package "passenger",
            :ensure   => :installed,
            :provider => :gem,
            :require  => package(:rails)

    path = path_for_gem(passenger)
    ruby = `which ruby`.chomp

    exec 'build-passenger',
         :cwd => path,
         :command => 'rake clean apache2',
         :creates => "#{path}/ext/apache2/mod_passenger.so"
         :require => [
           package(:passenger),
           service(:apache)
         ]

    passenger_module = <<-EOF
     LoadModule passenger_module #{path}/ext/apache2/mod_passenger.so
    EOF

    file '/etc/apache2/mods-available/passenger.load',
         :ensure   => :present,
         :contents => passenger_module,
         :require  => exec('build-passenger')

    passenger_conf = <<-EOF
     PassengerRoot #{path}
     PassengerRuby #{ruby}
    EOF

    file '/etc/apache2/mods-available/passenger.conf',
         :ensure   => :present,
         :contents => passenger_conf,
         :require  => exec('build-passenger')

    exec 'enable-passenger',
         :command => 'a2enmod passenger',
         :creates => '/etc/apache2/mods-enabled/passenger.load',
         :require => [
           file('/etc/apache2/mods-available/passenger.conf'),
           file('/etc/apache2/mods-available/passenger.load')
         ],
         :notify => service(:apache)
  end

  def rails
    package "rails", :ensure => :installed, :provider => :gem
  end

protected

  def path_for_gem(gem)
    begin
      gemspec = Gem::SourceIndex.from_installed_gems.find_name(gem).last
      gemspec_path = gemspec.loaded_from
      rubygems_base = File.join(File.dirname(gemspec_path), '..', 'gems')
      gem_path = File.join(rubygems_base, (gem+'-'+gemspec.version.to_s))
    rescue
      nil
    end
  end
end