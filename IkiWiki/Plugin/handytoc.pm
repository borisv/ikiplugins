#!/usr/bin/perl
# JavaScript Table Of Contents generator
# which applies ToC to pages matching a PageSpec.
package IkiWiki::Plugin::handytoc;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
	hook(type => "getsetup", id => "handytoc", call => \&getsetup);
	hook(type => "checkconfig", id => "handytoc", call => \&checkconfig);
	hook(type => "preprocess", id => "handytoc", call => \&preprocess);
	hook(type => "format", id => "handytoc", call => \&format);
}

sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => undef,
			section => "widget",
		},
		handytoc_pages => {
			type => "string",
			example => "docs/*",
			description => "Which pages to give a ToC to",
			safe => 0,
			rebuild => undef,
		},
		handytoc_css => {
			type => "string",
			example => "handytoc.css",
			description => "the location of the CSS file",
			safe => 0,
			rebuild => undef,
		},
		handytoc_js => {
			type => "string",
			example => "handytoc.js",
			description => "the location of the JavaScript file",
			safe => 0,
			rebuild => undef,
		},
		handytoc_defaults => {
			type => "hash",
			example => "handytoc_defaults => { levels => 1 }",
			description => "default arguments for handytoc",
			safe => 0,
			rebuild => undef,
		},
		handytoc_placeafter => {
			type => "string",
			example => "</h1>",
			description => "default placement of the ToC",
			safe => 0,
			rebuild => undef,
		},
}

sub checkconfig () {
    if (!defined $config{handytoc_pages})
    {
	$config{handytoc_pages} = "* and !*.*";
    }
    if (!defined $config{handytoc_css})
    {
	$config{handytoc_css} = 'handytoc.css';
    }
    if (!defined $config{handytoc_js})
    {
	$config{handytoc_js} = 'handytoc.js';
    }
    if (!defined $config{handytoc_placeafter})
    {
	$config{handytoc_placeafter} = '</h1>';
    }
    if ($config{handytoc_css} !~ /^(http|\/)/) # relative
    {
	$config{_handytoc_css_relative} = 1;
    }
    if ($config{handytoc_js} !~ /^(http|\/)/) # relative
    {
	$config{_handytoc_js_relative} = 1;
    }
}

my %tocpages;

sub preprocess (@) {
    my %params=@_;

    $tocpages{$params{destpage}}=\%params;
    if ($params{page} eq $params{destpage}) {
	return sprintf("\n<div id=\"htoc\"%s></div>\n",
		       ($params{class}
		       ? " class=\"$params{class}\""
		       : ''));
    }
    else {
	# use the default location for inlined pages
	return "";
    }
}

sub format (@) {
    my %params=@_;
    my $content=$params{content};
    my $page=$params{page};

    if (!pagespec_match($page, $config{handytoc_pages}))
    {
	return $content;
    }

    # if there is no </head> tag then we're probably in preview mode
    if (index($content, '</head>') < 0)
    {
	return $content;
    }

    my $scripting = render_css_and_js(%params);

    # add the CSS and Javascript at the end of the head section
    $content=~s!(</head>)!${scripting}$1!s;

    # ------------------------------
    # Add the TOC div if it isn't there
    # Place it after the first H1
    if ($content !~ /<div id="htoc"/o)
    {
	my $div = sprintf("\n<div id=\"htoc\"%s></div>\n",
		       (exists $tocpages{$page}->{class}
		       ? " class=\"$tocpages{$page}->{class}\""
		       : ''));
	$content =~ s#($config{handytoc_placeafter})#${1}\n${div}#i;
    }

    return $content;
} # format

# ------------------------------------------------------------
# Private Functions
# ----------------------------
sub render_css_and_js {
    my %params=@_;
    my $page=$params{page};

    my $baseurl = IkiWiki::baseurl($page);
    my @legal_args = qw(start levels ignoreh1 ignore_first_h1 ignore_only_one look_in_id);
    my %toc_args = ();
    foreach my $key (@legal_args)
    {
	if (exists $tocpages{$page}
	    and exists $tocpages{$page}->{$key}
	    and defined $tocpages{$page}->{$key})
	{
	    $toc_args{$key} = $tocpages{$page}->{$key};
	}
	elsif (exists $config{handytoc_defaults}
	    and exists $config{handytoc_defaults}->{$key}
	    and defined $config{handytoc_defaults}->{$key})
	{
	    $toc_args{$key} = $config{handytoc_defaults}->{$key};
	}
    }
    my @js_args = ();
    while (my ($key, $val) = each %toc_args)
    {
	push @js_args, ($val =~ /^\d+$/o ? "$key:$val" : "$key:'$val'");
    }
    my $js_args = join(', ', @js_args);

    my $handytoc_css = ($config{_handytoc_css_relative}
	? $baseurl . $config{handytoc_css}
	: $config{handytoc_css});
    my $jq_js = urlto("ikiwiki/jquery.min.js", $page);

    my $handytoc_js = ($config{_handytoc_js_relative}
	? $baseurl . $config{handytoc_js}
	: $config{handytoc_js});

    my $scripting = '';
    $scripting .=<<EOT;
<link rel="stylesheet" href="$handytoc_css" type="text/css" />
<script type='text/javascript' src='$jq_js'></script>
<script type='text/javascript' src='$handytoc_js'></script>
<script type="text/javascript">
\$(document).ready(function(){HandyToc.setup({$js_args});});
</script>
EOT
    return $scripting;
} # render_css_and_js

1
