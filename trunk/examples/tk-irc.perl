#!/usr/bin/perl
# $Id$

# A relatively simple IRC bot, if you call managing multiple channels
# on multiple networks, and displaying each channel in a separate Tk
# notebook tab... simple.

use warnings;
use strict;

use lib qw( lib ../lib );

use Tk;
use Tk::Tree;
use Tk::Label;
use Tk::Notebook;

use POE;
use POE::Component::IRC;

use Text::Conversation;

my %networks = (
	rh => {
		host => "irc.perl.org",
		port => 6667,
		chan => [ "#IRC.pm" ],
		nick => "thread",
	}
);

my $nb = $poe_main_window->NoteBook()->pack(-fill => 'both', -expand => 1);

my %tabs;
my %trees;
my %threaders;

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.

while (my ($net, $info) = each %networks) {
	# Create the component that will represent an IRC network.
	POE::Component::IRC->new($net);

	# Create the session that will interact with that network.
	POE::Session->create(
		inline_states => {
			_start          => \&bot_start,
			irc_001         => \&on_connect,
			irc_public      => \&on_message,
			irc_ctcp_action => \&on_message,
		},
		heap => {
			network => $net,
			%$info,
		},
	);
}

# Run the bot until it is done.

POE::Kernel->run();
exit 0;

# The bot session has started.  Register this session with the bot.
# Select a nickname.  Connect to a server.

sub bot_start {
	my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];

	$kernel->post( $heap->{network} => register => "all" );

	my $number = $$ % 1000;

	$kernel->post(
		$heap->{network} => connect => {
			Nick      => "$heap->{nick}$number",
			Username  => "threadbot$number",
			Ircname   => "Text::Conversation test bot number $number",
			Server    => $heap->{host},
			Port      => $heap->{port},
		}
	);
}

# The bot has successfully connected to a server.  Join a channel.

sub on_connect {
	my ($kernel, $bot, $heap) = @_[KERNEL, SENDER, HEAP];
	foreach my $channel (@{$heap->{chan}}) {
		$kernel->post($bot => join => $channel);
	}
}

# The bot has received a public message.  Parse it for commands, and
# respond to interesting things.

sub on_message {
	my ( $kernel, $heap, $bot, $who, $where, $msg ) = @_[
		KERNEL, HEAP, SENDER, ARG0, ARG1, ARG2
	];

	# Clean up input.
	$msg =~ s/\s+/ /g;
	$msg =~ s/^\s+//;
	$msg =~ s/\s+$//;

	# Determine our network, nickname, and channel.
	my $net     = $heap->{network};
	my $nick    = (split /!/, $who)[0];
	my $channel = $where->[0];

	# Does a Tk tab exist for this network and channel?  No?  Then
	# create one.  Also create a Text::Conversation object to thread
	# conversations in the channel.

	unless (exists $tabs{$net}{$channel}) {

		# Create the threader.
		my $threader = Text::Conversation->new();

		# Create a notebook tab for the channel.
		my $tab  = $nb->add( "$net$channel", -label => "$net$channel" );

		# Create a Tk tree widget to display threads.
		my $tree = $tab->Scrolled(
			'Tree',
			-separator        => '/',
			-background       => "white",
			-foreground       => "blue",
			-relief           => 'groove',
			-exportselection  => 1,
			-scrollbars       => 'oe',
			-height           => 40,
			-width            => 180,
			-itemtype         => 'text',
			-selectmode       => 'extended',
		);

		$tree->pack(
			-expand => 'yes',
			-fill   => 'both',
			-padx   => 15,
			-pady   => 15,
			-side   => 'top'
		);

		# Save all our creations.
		$tabs{$net}{$channel}       = $tab;
		$trees{$net}{$channel}      = $tree;
		$threaders{$net}{$channel}  = $threader;
	}

	my $threader = $threaders{$net}{$channel};
	my ($this_id, $referent_id, $debug_text) = $threader->observe($nick, $msg);

	# Rebuild the tree.
	# XXX - I'm throwing brute CPU at the problem of how to manage a
	# tree view.  There's some impedance mismatch between what observe()
	# returns and what TK::Tree expects.
	# XXX - I'm also cheating, using some internal methods of
	# Text::Conversation to populate the tree.  I should probably make
	# them public.

	my $tree = $trees{$net}{$channel};

	$tree->delete("all");
	foreach my $id ($threader->_id_list()) {
		$tree->add(
			$threader->_id_fully_qualified($id),
			-text => $threader->_id_get_text($id),
		);
	}
}
