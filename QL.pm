
=pod

=head1 NAME

XML::QL - An XML query language

=head1 VERSION

0.02 alpha

=head1 SYNOPSIS

$ql = 'WHERE
         <head>$head</head>
       ORDER-BY
         $head
       IN
         "file:REC-xml-19980210.xml"
       CONSTRUCT
         $head';

print XML::QL->query($sql);

=head1 DESCRIPTION

This module is an early implementation of a note published by the W3C called
"XML-QL: A Query Language for XML". XML-QL allows the user to query an XML
document much like a database, and describe a construct for output. Currently
this module only offers partial functionality as described in the specification,
and even some of that has been changed for ease of use. This documentation
will describe the fuctionality of this module as well as differences from the
XML-QL specification.

=head1 METHODS

=over4

=item query( "query" )

This is the only method required to use this module. This one method allows
the user to pass a valid XML-QL query to the module, and the return value is
the output.

=back4

=head1 XML-QL: The Query Language

The basic syntax consists of two parts, a WHERE clause to describe the data
to search for, and a CONSTRUCT clause to describe how to return the data that
is found.

=over4

=item WHERE

WHERE XML-searchstring [ORDER-BY variable [DESCENDING] [, variable [DESCENDING]] ] IN 'filename'

The WHERE clause can be separated into several parts. The first is the search string,
the second is an optional ORDER-BY clause much like ORDER BY in SQL, and last is
the required XML document file name. Each of these parts is described below.

=over4

=item XML-searchstring

The search string MUST be a valid XML snippet. This is one are where this module
differs from the specification. It has been implemented in this way so that the
search string may be parsed by the XML::Parser module.

The first step in building a query is to list the tags to search for in the document.
For example, consider the following search string:

	<BOOK>
		<AUTHOR></AUTHOR>
	</BOOK>

This search string will search for the AUTHOR tag nested within a BOOK tag. Note
however that no information has been selected for retrieval. In the following
example, we actually grab some information:

	<BOOK>
		<AUTHOR>$author</AUTHOR>
	</BOOK>

The variable name $author will grab the information that it finds withing this tag,
and makes this information avalable to us for use in the CONSTRUCT section of the
query. You will notice that variable names start with a dollar sign ($), as this
is called for by the specification.  In Perl, this means that if the query is enclosed
in double quotes, this dollar sign must be escaped.

In the following example we take it a step further by searching for books of that are
non-fiction:

	<BOOK TYPE='non-fiction'>
		<AUTHOR>$author</AUTHOR>
	</BOOK>

We can also express this as a regular expression:

	<BOOK TYPE='non-.*'>
		<AUTHOR>$author</AUTHOR>
	</BOOK>

This is another area where this module differs from the specification. The regular
expesssion ability as defined in the specification only allows for a subset of
the ability available in a Perl regular expression. With this module, the full range
of regular expression syntax has been made available. This also means that you
must also escape things such as periods(.), parenthesis (), and brackets ([]). All
non tag matched are case insensitive.

Now lets say that besides matching the TYPE, we also wanted to grab the value.
Consider this example:

	<BOOK TYPE='non-.* AS_ELEMENT $type'>
		<AUTHOR>$author</AUTHOR>
	</BOOK>

The AS_ELEMENT keyword allows you to save the matched value for later use in the
CONSTRUCT portion of the query.

=item ORDER-BY

The ORDER-BY clause allows to sort the data retrieved in the variables. You may
specify multiple variables, and specify DESCENDING for a reverse sort. This clause
is not required. For example:

ORDER-BY $type, $author DESCENDING

=item IN

The IN clause is a required clause that specifies the file name of the XML file.
This can be any URI, or it can be
a single file name enclosed in quotes. In later versions of this module there will
be support for multiple files, directories, and URLs. Following is an example:

IN 'REC-xml-19980210.xml'

=back4

=item CONSTRUCT

The CONSTRUCT construct allows you to specify a template for output. The template
will match character for character from the first space after the word CONSTRUCT
to the end of the XML-QL query. For example:

$ql = '(where clause...)
       CONSTRUCT
	Type: $type
	Author: $author';

The ouput of this will then be a carriage return, a tab, "Type: ", the contents
of $type, a carriage return, a tab, "Author: ", and the contents of $author. This
construct will be repeated for every match found and returned as a single string.

=back4

=head1 AUTHOR

Robert Hanson - Initial Version
rhanson@blast.net

Matt Sergeant - Only minor fixes so far
msergeant@ndirect.co.uk, sergeant@geocities.com

=head1 COPYRIGHT

Robert's Original licence B<was>:
I hereby reserve NO rights to this module, except for maybe a little recognition
if you decide to rewrite it and redistribute as your own.  Beyond that, you can
do whatever you want with this. I would just appreciate a copy of any improvements
to this module.

However that only stands for version 0.01 of the module. All versions above that
are released under the same terms as perl itself.

=cut

package XML::QL;

use strict;
use vars qw/$VERSION/;
use XML::Parser;
#use Data::Dumper;

$VERSION = 0.02;

my @match = ();
my @context = ();
my @curmat = ();
my @found = ();
my $construct;
my $uri;
my @orderby;
my $lastcall;

sub query
	{
	my ($class, $sql) = @_;
	buildMatchData($sql) || die "Unable to parse query string!\n";
	searchXMLfile($uri) || die "Unable to open file $uri\n";
	return createConstruct($construct);
	}

sub orderBy
	{
	my ($aval, $bval) = @_;
	my $numeric = 0;
	foreach (@orderby)
		{
		my $sortby = $_->{field};
		my $order = $_->{order};
		if ( ($aval->{$sortby} =~ /^\d*\.?\d*$/) && ($bval->{$sortby} =~ /^\d*\.?\d*$/) )
			{
			$numeric = 1;
			}
		if ($numeric)
			{
			if ($order eq 'DESCENDING')
				{
				return ($bval->{$sortby} <=> $aval->{$sortby}) if ($bval->{$sortby} != $aval->{$sortby});
				}
			else
				{
				return ($aval->{$sortby} <=> $bval->{$sortby}) if ($aval->{$sortby} != $bval->{$sortby});
				}
			}
		else
			{
			if ($order eq 'DESCENDING')
				{
				return ($bval->{$sortby} cmp $aval->{$sortby}) if ($bval->{$sortby} ne $aval->{$sortby});
				}
			else
				{
				return ($aval->{$sortby} cmp $bval->{$sortby}) if ($aval->{$sortby} ne $bval->{$sortby});
				}
			}
		}
	return 0;
	}

sub createConstruct
	{
	my ($construct) = @_;
	my $ret_val = '';
	@found = sort { orderBy($a,$b) } (@found) if ( scalar(@orderby) > 0 );
	foreach my $match (@found)
		{
		my $tmp = $construct;
		foreach my $key ( keys(%{$match}) )
			{
			$tmp =~ s/\$$key/$match->{$key}/eg;
			}
		$ret_val .= $tmp;
		}
	return $ret_val;
	}

sub searchXMLfile
	{
	my ($uri) = @_;

	my $ql = new XML::Parser(Handlers => {Start => \&handle_start, End => \&handle_end, Char => \&handle_char});

	if ($uri =~ /^(file:|https?:|ftp:|gopher:)/) {
		eval "use LWP::UserAgent;";
		my $ua = LWP::UserAgent->new;
		$ua->env_proxy;

		my $req = new HTTP::Request 'GET',$uri;
		my $doc = $ua->request($req)->content;
	
		$ql->parsestring($doc);
	}
	else {
		# Assume it's a file
		$ql->parsefile($uri);
	}

	#open OUT, ">debug.txt";
	#print OUT Data::Dumper->Dump([\@match, \@context, \@curmat, \@found],['match', 'context', 'curmat', 'found']);
	#close OUT;
	}

sub buildMatchData
	{
	my ($sql) = @_;
	my ($where, $orderby);
	if ( $sql =~ /^\s*
					(WHERE)\s+(.*?)\s+
					(?:(ORDER-BY)\s+(.*?)\s+)?
					(IN)\s+(.*?)\s+
					(CONSTRUCT)\s+(.*)$/isx )
		{
		for ( my $i = 1; $i <= 8; $i += 2 )
			{
			no strict "refs";
			next if (! defined(${"$i"}) );
			my $val = $i + 1;
			$where = ${"$val"} if (${"$i"} eq 'WHERE');
			$orderby = ${$val} if (${$i} eq 'ORDER-BY');
			$uri = ${$val} if (${$i} eq 'IN');
			$construct = ${$val} if (${$i} eq 'CONSTRUCT');
			}
		}
	else
		{
		return 0;
		}

	# check URI syntax
	if ( $uri =~ /^['"](.*)['"]$/ )
		{
		$uri = $1;
		}
	else
		{
		return 0;
		}

	# handle order-by
	if ($orderby)
		{
		$orderby =~ s/^\s*//;
		$orderby =~ s/\s*$//;
		my @tmporder = split(/\s*,\s*/, $orderby);
		foreach my $tmp (@tmporder)
			{
			if ( $tmp =~ /^\$([a-zA-Z0-9]+)(?:\s+(DESCENDING))?$/i )
				{
				if ( defined($2) )
					{
					push @orderby, { 'field' => $1, 'order' => 'DESCENDING'};
					}
				else
					{
					push @orderby, { 'field' => $1, 'order' => 'ASCENDING'};
					}
				}
			else
				{
				return 0
				}
			}
		}

	my $ql = new XML::Parser(Handlers => {Start => \&where_start, End => \&where_end, Char => \&where_char});
	$ql->parse($where);
	return 1;
	}

sub where_start
	{
	my $expat = shift;
	my $element = shift;
	my %attributes = @_;
	push @match, {'type' => 'starttag', 'element' => $element, 'char' => '', 'attrib' => \%attributes };
	}

sub where_end
	{
	my $expat = shift;
	my $element = shift;
	push @match, {'type' => 'endtag', 'element' => $element, 'char' => '', 'attrib' => {}};
	}

sub where_char
	{
	my $expat = shift;
	my $string = shift;
	$string =~ s/^\s+//; # strip leading white space
	$string =~ s/\s+$//; # strip following white space
	push @match, {'type' => 'char', 'element' => '', 'char' => $string, 'attrib' => {}} if ($string ne '');
	}

sub handle_start
	{
	my $expat = shift;
	my $element = shift;
	my %attributes = @_;
	$lastcall = "open$element";
	push @context, $element;
	my $limit = scalar(@curmat);
	for (my $i = 0; $i < $limit; $i++ )
		{
		if ( ! $curmat[$i]->{done} )
			{
			# If current match not done...
			if ( $match[$curmat[$i]->{ptr}]->{type} eq 'starttag' )
				{
				# If type of cur match equals starttag...
				if ( $match[$curmat[$i]->{ptr}]->{element} eq $element )
					{
					# If the target tag equals the current element...
					# Advance match

					my %tmphash = %{$curmat[$i]};
					push @curmat, \%tmphash;

					$curmat[$i]->{ptr}++ if ( matchAttributes($i, %attributes) );
					}
				}
			}
		}
	if ( $match[0]->{type} eq 'starttag' )
		{
		# If the start of the match is a starttag...
		if ( $match[0]->{element} eq $element )
			{
			# If the element matches the target element
			push @curmat, {'ptr' => 0, 'done' => 0, 'fail' => scalar(@context)};
			matchAttributes(scalar(@curmat) - 1, %attributes);
			$curmat[scalar(@curmat) - 1]->{ptr}++;
			}
		}
	}

sub matchAttributes
	{
	my ($i, %attributes) = @_;
	my %match_attribs = %{$match[$curmat[$i]->{ptr}]->{attrib}};
	foreach my $key ( keys(%match_attribs) )
		{
		if ( $match_attribs{$key} =~ /^(.*?)\s+AS_ELEMENT\s+\$([a-zA-Z0-9]+)\s*$/i )
			{
			my $tmpfind = $1;
			my $tmpvar = $2;
			if ( $attributes{$key} =~ /^$tmpfind$/i )
				{
				$curmat[$i]->{vars}->{$tmpvar} = $attributes{$key};
				}
			else
				{
				$curmat[$i]->{done} = 1;
				return 0;
				}
			}
		elsif ( $match_attribs{$key} =~ /^\s*\$([a-zA-Z0-9]+)\s*$/ )
			{
			$curmat[$i]->{vars}->{$1} = $attributes{$key};
			}
		elsif ( $attributes{$key} !~ /^$match_attribs{$key}$/i )
			{
			$curmat[$i]->{done} = 1;
			return 0;
			}
		}
	return 1;
	}


sub handle_end
	{
	my $expat = shift;
	my $element = shift;
	if ($lastcall eq "open$element")
		{
		# To fix Char handler not being called on an empty string
		handle_char($expat, '');
		}
	$lastcall = "close$element";
	pop @context;
	for (my $i = 0; $i < scalar(@curmat); $i++ )
		{
		if ( ! $curmat[$i]->{done} )
			{
			# If current match not done...
			if ( $match[$curmat[$i]->{ptr}]->{type} eq 'endtag' )
				{
				# If type of cur match equals endtag...
				if ( $match[$curmat[$i]->{ptr}]->{element} eq $element )
					{
					# If the target tag equals the current element...
					# Advance match
					$curmat[$i]->{ptr}++;
					if ($curmat[$i]->{ptr} == scalar(@match))
						{
						# if the match pointer has been advanced to the end of the match...
						# Match is done!
						my %tmp = %{$curmat[$i]->{vars}};
						push @found, \%tmp;
						$curmat[$i]->{done} = 1;
						$curmat[$i]->{reason} = 'matched query';
						}
					}
				}
			}
		if ( ( ! $curmat[$i]->{done} ) && ( scalar(@context) < $curmat[$i]->{fail} ) )
			{
			$curmat[$i]->{done} = 1;
			$curmat[$i]->{reason} = "out of context on $element";
			}
		}
	}

sub handle_char
	{
	my $expat = shift;
	my $string = shift;
	$lastcall = "char";
	$string =~ s/^\s+//; # strip leading whitespace
	$string =~ s/\s+$//; # strip following white space
	for (my $i = 0; $i < scalar(@curmat); $i++ )
		{
		if ( ! $curmat[$i]->{done} )
			{
			# If current match not done...
			if ( $match[$curmat[$i]->{ptr}]->{type} eq 'char' )
				{
				# If type of cur match equals starttag...
				if ( $match[$curmat[$i]->{ptr}]->{char} =~ /^(.*?)\s+AS_ELEMENT\s+\$([a-zA-Z0-9]+)\s*$/i )
					{
					my $tmpfind = $1;
					my $tmpvar = $2;
					if ( $string =~ /^$tmpfind$/i )
						{
						$curmat[$i]->{vars}->{$tmpvar} = $string;
						$curmat[$i]->{ptr}++;
						}
					else
						{
						$curmat[$i]->{done} = 1;
						$curmat[$i]->{reason} = "Does not match string $string";
						}
					}
				elsif ( $string =~ /^$match[$curmat[$i]->{ptr}]->{char}$/i )
					{
					# If the target tag equals the current element...
					# Advance match
					$curmat[$i]->{ptr}++;
					}
				elsif ( $match[$curmat[$i]->{ptr}]->{char} =~ /^\$([a-zA-Z0-9]+)$/ )
					{
					$curmat[$i]->{vars}->{$1} = $string;
					$curmat[$i]->{ptr}++;
					}
				else
					{
					$curmat[$i]->{done} = 1;
					$curmat[$i]->{reason} = "Does not match string $string";
					}
				}
			}
		}
	}

1;
