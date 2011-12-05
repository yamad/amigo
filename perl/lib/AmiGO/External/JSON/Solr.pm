=head1 AmiGO::External::JSON::Solr

Specialize onto external document store resource.

=cut

use utf8;
use strict;
use Carp;

package AmiGO::External::JSON::Solr;

use base ("AmiGO::External::JSON");
use Data::Dumper;


=item new

Arguments: (optional) full URL as string including the final slash.
e.g.: http://skewer.lbl.gov:8080/solr/
No argument will use AmiGO's internal GOlr url.

=cut
sub new {

  ##
  my $class = shift;
  my $self = $class->SUPER::new();

  #my $args = shift || {};
  my $target = shift || $self->amigo_env('AMIGO_PUBLIC_GOLR_URL');
  #my $host = $args->{host} || die "need a host: $!";

  ## http://skewer.lbl.gov:8080/solr/select?qt=standard&indent=on&wt=json&version=2.2&rows=10&start=0&fl=*%2Cscore&q=id:%22GO:0022008%22
  $self->{AEJS_BASE_HASH} =
    {
     'qt' => 'standard',
     'indent' => 'on',
     'wt' => 'json',
     'version' => 2.2,
     'rows' => 10,
     'start' => 0,
     'fl' => '*%2Cscore',
    };

  $self->{AEJS_BASE_URL} = $target . 'select?';
  $self->{AEJS_LAST_URL} = undef;
  $self->{AEJS_RESPONSE} = undef;

  bless $self, $class;
  return $self;
}


=item _query_url

Arguments: Post "select?" query string or internal hash manipulation.
Return: query string

Helper function (not meant to be called directly) to get the url of
the current state of the object.

Does not change object state.

=cut
sub _query_url {

  my $self = shift;
  my $qstr = shift || undef;

  $self->kvetch("base hash: " . Dumper($self->{AEJS_BASE_HASH}));

  ## Create URL.
  my $url = $self->{AEJS_BASE_URL} .
    $self->hash_to_query_string($self->{AEJS_BASE_HASH});

  ## Add more if it is defined as an argument.
  $url = $url . '&' . $qstr if $qstr;

  ## Make query against resource and try to perlify it.
  $self->kvetch("url: " . $url);

  return $url;
};


=item query

Arguments: Post "select?" query string or internal hash manipulation.
Return: true or false on minimal success

Basically, the main way subclasses should be handling Solr queries.
Also updates last URL tried, count, etc.

=cut
sub query {

  my $self = shift;
  my $qstr = shift || undef;
  my $retval = 0;

  $self->kvetch("base hash: " . Dumper($self->{AEJS_BASE_HASH}));

  ## Create URL.
  my $url = $self->_query_url($qstr);

  ## Update last query url.
  $self->{AEJS_LAST_URL} = $url;

  ## Make query against resource and try to perlify it.
  $self->kvetch("url: " . $url);

  $self->get_external_data($url);
  my $doc_blob = $self->try();

  #$self->kvetch("doc_blob: " . Dumper($doc_blob));

  ## Make sure we got something.
  if( ! $self->empty_hash_p($doc_blob) &&
      $doc_blob->{response} ){
    $self->{AEJS_RESPONSE} = $doc_blob;
    $retval = 1;
  }

  return $retval;
}


=item variables

Arguments: n/a
Returns: aref of current variable keys

=cut
sub variables {

  my $self = shift;
  my $retref;

  foreach my $k (keys %{$self->{AEJS_BASE_HASH}} ){
    push @$retref, $k;
  }

  return $retref;
}


=item get_variable

Arguments: string name of solr variable.
Returns: variable or undef

=cut
sub get_variable {

  my $self = shift;
  my $qkey = shift || undef;
  my $retval = undef;

  if( defined $qkey && defined $self->{AEJS_BASE_HASH}{$qkey} ){
    $retval = $self->{AEJS_BASE_HASH}{$qkey};
  }

  return $retval;
}


=item set_variable

Arguments: string name of solr variable, value
Returns: the value of the set variable

=cut
sub set_variable {

  my $self = shift;
  my $qkey = shift || undef;
  my $qval = shift || undef;
  my $retval = $qval;

  if( defined $qkey ){
    $self->{AEJS_BASE_HASH}{$qkey} = $qval;
  }

  return $qval;
}


=item add_variable

Arguments: string name of solr variable, value to be added to key
Returns: the value of the added variable

=cut
sub add_variable {

  my $self = shift;
  my $qkey = shift || undef;
  my $qval = shift || undef;
  my $retval = $qval;

  if( defined $qkey ){
    if( ! defined $self->{AEJS_BASE_HASH}{$qkey} ){
      $self->{AEJS_BASE_HASH}{$qkey} = $qval;
    }elsif( defined $self->{AEJS_BASE_HASH}{$qkey} &&
	    ref($self->{AEJS_BASE_HASH}{$qkey}) eq 'ARRAY' ){
      push @{$self->{AEJS_BASE_HASH}{$qkey}}, $qval;
    }else{
      my $tmp_val = $self->{AEJS_BASE_HASH}{$qkey};
      $self->{AEJS_BASE_HASH}{$qkey} = [];
      push @{$self->{AEJS_BASE_HASH}{$qkey}}, $tmp_val;
      push @{$self->{AEJS_BASE_HASH}{$qkey}}, $qval;
    }
  }

  return $qval;
}


=item url

Return: the last url used as a string.

=cut
sub url {
  my $self = shift;
  return $self->{AEJS_LAST_URL};
}


=item total

Return: int or undef

Total number of possible docs found during last query.

=cut
sub total {

  my $self = shift;
  my $retval = undef;

  ## Make sure we got something.
  if( $self->{AEJS_RESPONSE}{response} &&
      $self->{AEJS_RESPONSE}{response}{numFound} ){
    $retval = $self->{AEJS_RESPONSE}{response}{numFound};
  }

  return $retval;
}


=item count

Return: int or undef

Count of returned docs found during last query.

=cut
sub count {

  my $self = shift;
  my $retval = undef;

  ## Make sure we got something.
  if( $self->{AEJS_RESPONSE}{response} &&
      $self->{AEJS_RESPONSE}{response}{docs} ){
    $retval = scalar(@{$self->{AEJS_RESPONSE}{response}{docs}});
  }

  return $retval;
}


=item docs

Return: docs as aref or undef

The docs found during last query.

=cut
sub docs {

  my $self = shift;
  my $retval = undef;

  ## Make sure we got something.
  if( $self->{AEJS_RESPONSE}{response} &&
      $self->{AEJS_RESPONSE}{response}{docs} ){
    $retval = $self->{AEJS_RESPONSE}{response}{docs};
  }

  return $retval;
}


=item first_doc

Return: doc or undef

The first doc found during last query.

=cut
sub first_doc {

  my $self = shift;
  my $retval = undef;

  ## Make sure we got something.
  if( $self->{AEJS_RESPONSE}{response} &&
      $self->{AEJS_RESPONSE}{response}{docs} &&
      $self->{AEJS_RESPONSE}{response}{docs}[0] ){
    $retval = $self->{AEJS_RESPONSE}{response}{docs}[0];
  }

  return $retval;
}


=item _ready_paging

Args: n/a
Return: n/a

A helper function to make sure paging stays sane. Called in first part
of functions that deal with paging.

Changes object state.

=cut
sub _ready_paging {

  my $self = shift;

  ## Our index is either correct or set to 1;
  if( ! defined $self->{AEJS_BASE_HASH}{index} ){
    # $curr_index = $self->{AEJS_BASE_HASH}{index};
    # }else{
    $self->{AEJS_BASE_HASH}{index} = 1;
    #   $curr_index = 1;
  }
}


=item next_page_url

Args: n/a
Return: url for the _next_ "page" on the service.

=cut
sub next_page_url {

  my $self = shift;
  my $returl = undef;

  $self->_ready_paging();

  ## Our current is either correct or set to 1;
  my $curr_index = $self->{AEJS_BASE_HASH}{index};
  $self->{AEJS_BASE_HASH}{index}++;
  $returl = $self->_query_url();
  $self->{AEJS_BASE_HASH}{index} = $curr_index;

  return $returl;
}


## No longer have to worry about open connections.
sub DESTROY {
  my $self = shift;
  #if( defined $self->{EXT_DB} ){
  #$self->{EXT_DB}->disconnect();
  #$self->{EXT_DB} = undef;
  #}
}



1;
