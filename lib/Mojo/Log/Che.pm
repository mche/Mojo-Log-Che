package Mojo::Log::Che;
use Mojo::Base 'Mojo::Log';

use Carp 'croak';
use Fcntl ':flock';
use Mojo::File;

has paths => sub { {} };
has handlers => sub { {} };

# Standard log levels
my %LEVEL = (debug => 1, info => 2, warn => 3, error => 4, fatal => 5);

sub new {
  my $self = shift->SUPER::new(format => \&_format, @_);
  $self->unsubscribe('message')->on(message => \&_message);
  return $self;
}

sub handler {
  my ($self, $level) = @_;
  
  my $handler = $self->handlers->{$level};
  return $handler
    if $handler;
  
  my $path = shift->path;
  my $path_level = $self->paths->{$level};
  my $is_dir = -d -w $path
    if $path;
  
  my $file;
  if ($is_dir) {# DIR
    # relative path for level
    chop($path)
      if $path =~ /\/$/;
    
    $file = sprintf "%s/%s", $path, $path_level ||"$level.log";
  }
  elsif ($path_level) {# absolute FILE for level
    $file = $path_level;
  }
  else {
    #~ croak "Cant create log handler for level=[$level] and path=[$path] (also check filesystem permissions)";
    return; # Parent way to handle
  }
  
  $handler = Mojo::File->new($file)->open('>>:encoding(UTF-8)')
    or croak "Cant create log handler for [$file]";
  
  $self->handlers->{$level} = $handler;
  
  return $handler;
};

sub append {
  my ($self, $msg, $handle) = @_;

  return unless $handle ||= $self->handle;
  flock $handle, LOCK_EX;
  $handle->print( $msg)
    or croak "Can't write to log: $!";
  flock $handle, LOCK_UN;
}

my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @wday = qw(Sn Mn Ts Wn Th Fr St);
sub _format {
  my ($time, $level) = (shift, shift);
  $level = "[$level] "
    if $level //= '';
  
  my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($time);
  $time = sprintf "%s %s %s %s:%s:%s", $wday[$wday], $mday, map(length == 1 ? "0$_" : $_, $mon[$mon], $hour, $min, $sec);
  
  return "[$time] $level" . join "\n", @_, '';
}


sub _message {
  my ($self, $level) = (shift, shift);

  return unless !$LEVEL{$level} || $self->is_level($level);

  my $max     = $self->max_history_size;
  my $history = $self->history;
  my $time = time;
  push @$history, my $msg = [$time, $level, @_];
  shift @$history while @$history > $max;
  
  if (my $handle = $self->handler($level)) {
    return $self->append($self->format->($time, '', @_), $handle);
  }

  # as parent
  return $self->append($self->format->(@$msg));
  
}

sub AUTOLOAD {
  my $self = shift;

  my ($package, $method) = our $AUTOLOAD =~ /^(.+)::(.+)$/;
  Carp::croak "Undefined log level(subroutine) &${package}::$method called"
    unless Scalar::Util::blessed $self && $self->isa(__PACKAGE__);

  return $self->_log( $method => @_ );
  
}

our $VERSION = '0.02';

=encoding utf8

Доброго всем

=head1 Mojo::Log::Che

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 VERSION

0.02

=head1 NAME

Mojo::Log::Che - Little child of big parent Mojo::Log.

=head1 SYNOPSIS

  use Mojo::Log::Che;

  # Log to STDERR
  my $log = Mojo::Log::Che->new;

  # Customize log file location and minimum log level
  my $log = Mojo::Log::Log->new(path => '/var/log/mojo.log', level => 'warn');
  
  # MAIN THINGS
  # Set "path" to folder + have default "paths" for levels
  my $log = Mojo::Log::Log->new(path => '/var/log/mojo');
  $log->warn('This might be a problem');#  /var/log/mojo/warn.log
  $log->error('Garden variety error'); #  /var/log/mojo/error.log
  $log->foo('BAR here');#  /var/log/mojo/foo.log
  
  # set "path" to folder + set custom relative "paths"
  my $log = Mojo::Log::Log->new(path => '/var/log/mojo', paths=>{debug=>'dbg.log', foo=>'myfoo.log'});
  $log->debug('Not sure what is happening here'); #  /var/log/mojo/dbg.log
  $log->warn('This might be a problem');# /var/log/mojo/warn.log
  $log->foo('BAR here');#  /var/log/mojo/myfoo.log
  
  # set "path" to file + have default "paths" for levels
  my $log = Mojo::Log::Log->new(path => '/var/log/mojo.log');
  $log->debug('Not sure what is happening here'); #  /var/log/mojo.log
  $log->warn('This might be a problem');#  /var/log/mojo.log
  $log->foo('BAR here');# /var/log/mojo.log
  
  # Log to STDERR + set custom absolute "paths"
  $log->path(undef); # none path
  $log->paths->{'error'} = '/var/log/error.log'; # absolute only error level
  $log->info(...); # log to STDERR
  

=head1 DESCRIPTION

This B<Mojo::Log::Che> is a extended logger module for L<Mojo> projects.

=head1 EVENTS

B<Mojo::Log::Che> inherits all events from L<Mojo::EventEmitter> and can emit the
following new ones.

=head2 message

See parent L<Mojo::Log/"message">.

=head1 ATTRIBUTES

B<Mojo::Log::Che> inherits all attributes from L<Mojo::Log> and implements the
following new ones.

=head2 handle

See parent L<Mojo::Log/"handle">. This is default handler for file L</"path">. There are diffrent L</"handlers"> when L</"path"> as forder/dir or defined L</"paths"> for levels. Compatible L<Mojo::Log> reason.

=head2 handlers

Hashref of created file handlers for standard and custom levels.

  $log->handlers->{'foo'} = IO::Handle->new();

=head2 path

See parent L<Mojo::Log/"path">. Log file path used by L</"handle"> if L</"path"> is file or undef. Compatible reason.

=head2 paths

Hashref map level names to absolute or relative to L</"path">

  $log->path('/var/log'); # folder relative
  $log->paths->{'error'} = 'err.log';
  $log->error(...);#  /var/log/err.log
  $log->info(...); # log to filename as level name /var/log/info.log
  
  $log->path(undef); # none 
  $log->paths->{'error'} = '/var/log/error.log'; # absolute path only error level
  $log->info(...); # log to STDERR


=head1 METHODS

B<Mojo::Log::Che> inherits all methods from L<Mojo::Log> and implements the
following new ones.

=head2 handler($level)

Return undef when L</"path"> undefined or L</"path"> is file or has not defined L</"paths"> for $level. In this case L<Mojo::Log/"handle"> will return default handler.

Return file handler overwise.

=head1 AUTOLOAD

Autoloads nonstandard/custom levels excepts already defined keywords of this and parent modules L<Mojo::Log>, L<Mojo::EventEmitter>, L<Mojo::Base>:

  qw(message _message format _format handle handler handlers
  history level max_history_size  path paths append debug  error fatal info
  is_level  new warn  catch emit  has_subscribers on  once subscribers unsubscribe
  has  attr tap _monkey_patch import)

and maybe anymore!


  $log->foo('bar here');

That custom levels log always without reducing log output outside of level.

=head1 SEE ALSO

L<Mojo::Log>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojo-Log-Che/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2017 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
