package Net::Google::FederatedLogin::Extension;
# ABSTRACT: something that can find the OpenID endpoint

use Moose;

has ns          => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

has uri         => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

has attributes  => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
    trigger     => \&_flatten_attributes,
);

around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    
    my $args;
    if(@_ == 1 && ref $_[0] eq 'HASH') {
        $args = $_[0];
    } else {
        $args = {@_};
    }
    if($args->{cgi}) {
        my $new_args;
        if($args->{uri}) {
            $new_args = _extract_attributes_by_uri($args);
        } elsif($args->{ns}) {
            $new_args = _extract_attributes_by_ns($args);
        } else {
            die 'Unable to determine extension details';
        }
        return $class->$orig($new_args);
    } else {
        return $class->$orig(@_);
    }
};

sub _extract_attributes_by_uri {
    my $args = shift;
    
    my $cgi = $args->{cgi};
    my $uri = $args->{uri};
    
    my @openid_params = grep {/^openid\./} $cgi->param();
    (my $ns_param) = grep {$cgi->param($_) eq $uri} grep {/^openid\.ns\./} @openid_params;
    if($ns_param) {
        $args->{ns} = substr($ns_param, 10);
        return _extract_attributes_by_ns($args);
    }
    
    return $args;
}

sub _extract_attributes_by_ns {
    my $args = shift;
    
    my $cgi = $args->{cgi};
    my $ns = $args->{ns};
    
    $args->{uri} ||= $cgi->param("openid.ns.$ns");
    
    my $prefix = "openid.$ns.";
    my $prefix_len = length($prefix);
    my %attributes = (map {substr($_, $prefix_len) => scalar $cgi->param($_)} grep {/^\Q$prefix\E/} $cgi->param());
    $args->{attributes} = \%attributes;
    
    return $args;
}

sub get_parameter_string {
    my $self = shift;
    my $ns = $self->ns;
    
    my $params = sprintf 'openid.ns.%s=%s', $ns, $self->uri;
    
    my $attributes = $self->attributes;
    $params .= _parameterise_hash("openid.$ns", $attributes);
    
    return $params;
}

sub _parameterise_hash {
    my $prefix = shift;
    my $hash = shift;
    
    my $params = '';
    $params .= sprintf '&%s.%s=%s', $prefix, $_, $hash->{$_} foreach(sort keys %$hash);
    return $params;
}

sub get_parameter {
    my $self = shift;
    my $param = shift;
    
    return $self->attributes->{$param};
}

sub set_parameter {
    my $self = shift;
    my %params = @_;
    
    _flatten_hash(\%params);
    
    $self->attributes->{$_} = $params{$_} foreach keys %params;
}

sub _flatten_attributes {
    my $self = shift;
    my $attributes = shift;
    
    _flatten_hash($attributes);
}

sub _flatten_hash {
    my $hash = shift;
    
    foreach my $key (keys %$hash) {
        my $value = $hash->{$key};
        if(ref $value eq 'HASH') {
            _flatten_hash($value);
            $hash->{"$key.$_"} = $value->{$_} foreach keys %$value;
            delete $hash->{$key};
        }
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
