package App::Netdisco::Web::Plugin::API::NodeIP;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Extensible;

use Dancer::Plugin::DBIC 'schema';
use Data::Dumper;

use JSON qw//;
use Dancer::Exception qw(:all);

use App::Netdisco::Web::Plugin;
# Set serializer to JSON
set serializer => 'JSON'; 


sub api_array_json {
    my $items = shift;
    my @results;
    foreach my $item (@{$items}) {
        print "1\n";
        my $c = {};
        my $columns = $item->{_column_data};
        foreach my $col (keys %{$columns}) {
            $c->{$col} = $columns->{$col};
        }
        push @results, $c;
    }
    return (\@results);
};

get '/api/node/search' => sub {
    my $para = params;
    my $search = {};
    # Generate a hashref of search terms. 
    foreach my $param (keys %{$para}) {
        if ($param ne 'return_url') {
            $search->{$param} = $para->{$param};
        }
    }
    my @ips;
    try {
       @ips = schema('netdisco')->resultset('Node')->search($search);
    };
    return api_array_json(\@ips);
};

get '/api/node/:node/:method' => sub {
    my $node = params->{node};
    my $method = params->{method};
    # Make sure $node is actually a mac address in the proper format.
    if (!($node =~ m/([0-9a-f]{2}:){5}([0-9a-f]{2})/)){
        status 400;
        return ({ error => "Not a MAC Address. Address must follow the format aa:bb:cc:dd:ee:ff." });
    }
    try {
        my @nodesearch = schema('netdisco')->resultset('Node')->search({ mac => $node});
        # Searching by mac there should be only one result
        my $node = $nodesearch[0]->$method;

        # ResultSets need to be converted to an array of hashes before being returned.
        # Dancer's JSON serializer doesn't like the objects
        if (ref($node) =~ m/ResultSet/) {
            my @nodes = $node->all;
            return api_array_json(\@nodes);
        }
        else {
            my $nodes = $node;
            return $nodes->{_column_data};
        }
    } catch {
        my ($exception) = @_;
        print Dumper($exception);
        if ($exception =~ m/Can\'t call method "$method" on an undefined value/) {
            status 404;
            return ({ error => "MAC Address not found."});
        }
        status 400;
        return ({ error => "Invalid collection $method." });
    };
};
