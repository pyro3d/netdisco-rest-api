package App::Netdisco::Web::Plugin::API::Device;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Extensible;

use Dancer::Plugin::DBIC 'schema';
use Data::Dumper;

use JSON qw//;
use Dancer::Exception qw(:all);


use App::Netdisco::Web::Plugin;
my $JSON = JSON->new->utf8;
$JSON->convert_blessed(1);
$JSON->allow_blessed(1);
set serializer => 'JSON'; # Dancer2::Serializer::JSON

sub api_array_json {
    my $items = shift;
    my @results;
    foreach my $item (@{$items}) {
        my $c = {};
        my $columns = $item->{_column_data};
        foreach my $col (keys %{$columns}) {
            $c->{$col} = $columns->{$col};
        }
        push @results, $c;
    }
    return (\@results);
};

get '/api/device/all' => sub {
    my @devices=schema('netdisco')->resultset('Device')->all;
    return api_array_json(\@devices);
};

get '/api/device/search' => sub {
    my $para = params;
    my $search = {};
    foreach my $param (keys %{$para}) {
        if ($param ne 'return_url') {
            $search->{$param} = $para->{$param};
        }
    }
    print Dumper($search);
    my @devices;
    try {
       @devices=schema('netdisco')->resultset('Device')->search($search);
    };
    return api_array_json(\@devices);
};

get '/api/device/:device' => sub {
    my $dev = params->{device};
    print "$dev\n";
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($dev) or send_error('Bad Device', 404);
    return $device->{_column_data};
};

get '/api/device/:device/modules' => sub {
    my $dev = params->{device};
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($dev) or send_error('Bad Device', 404);
    my @modules = $device->modules;
    return api_array_json(\@modules);

};

get '/api/device/:device/vlans' => sub {
    my $dev = params->{device};
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($dev) or send_error('Bad Device', 404);
    my @vlans = $device->vlans;
    return api_array_json(\@vlans);
};

get '/api/device/:device/ports' => sub {
    my $dev = params->{device};
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($dev);
    my @ports = $device->ports->all;
    my @results;
    foreach my $item (@ports) {
        my $c = {};
        my $columns = $item->{_column_data};
        foreach my $col (keys %{$columns}) {
            $c->{$col} = $columns->{$col};
        }
        my @vlans = $item->vlans->all ;
        my @pvlans;
        my @vl = $item->port_vlans;
        foreach my $item (@vlans) {
            push @pvlans, $item->{_column_data}->{vlan};
        }
        $c->{vlans}=\@pvlans;
        push @results, $c;
    }
    return \@results;
};

get qr{/api/device/(?<ip>.*)/port/(?<port>.*)/nodes$} => sub {
    my $param =captures;
    my @ports = schema('netdisco')->resultset('Device')
      ->search_for_device($$param{ip})->ports->search({port => $$param{port}});
    my @nodes = $ports[0]->nodes;
    return api_array_json(\@nodes);
};

get qr{/api/device/(?<ip>.*)/port/(?<port>.*)/neighbor$} => sub {
    my $param =captures;
    my @ports = schema('netdisco')->resultset('Device')
      ->search_for_device($$param{ip})->ports->search({port => $$param{port}});
    my @neighbors = $ports[0]->neighbor;
    return api_array_json(\@neighbors);
};

get qr{/api/device/(?<ip>.*)/port/(?<port>.*)/power$} => sub {
    my $param =captures;
    my @ports = schema('netdisco')->resultset('Device')
      ->search_for_device($$param{ip})->ports->search({port => $$param{port}});
    my @neighbors = $ports[0]->power;
    return api_array_json(\@neighbors);
};

get qr{/api/device/(?<ip>.*)/port/(?<port>.*)} => sub {
    my $param =captures;
    my $port;
    try {
        my @ports = schema('netdisco')->resultset('Device')
          ->search_for_device($$param{ip})->ports->search({port => $$param{port}});
        my @vlans = $ports[0]->vlans->all ;
        my @pvlans;
        foreach my $item (@vlans) {
            push @pvlans, $item->{_column_data}->{vlan};
        }
        $port = @{api_array_json(\@ports)}[0];
        $port->{vlans} = \@pvlans;
    };
    return $port if defined $port;
    status 404;
    return { message=>"Port not found" };
};

true;
