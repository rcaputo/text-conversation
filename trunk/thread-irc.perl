#!/usr/bin/perl
# $Id$

use warnings;
use strict;
use lib qw( lib /home/troc/projects/todo-add-to-repository/know/know-2 );

use Tk;
use Tk::Tree;
use Tk::Label;
use Tk::Notebook;

use Util::Common qw(try_uptime);
use Util::Backend;
use Text::Conversation;

select STDOUT; $| = 1;

### Set up display.

use POE;
my $top = $poe_main_window; # new MainWindow( -title => "IRC Threads" );

my $nb = $top->NoteBook()->pack( -fill => 'both', -expand => 1);

my %tabs;
my %trees;
my %threaders;

$top->update();

### PROCEDURE DIVISION.

svc_run_poe("10.0.0.25", 54321);
exit 0;

### Handle IRC messages.

sub on_ctcp_action {
	my $msg = shift;
	return unless defined $msg->message();

	my $response = try_all(
		$msg,
		$msg->message(),
		"public",
		$msg->nick(),
		0,
	);
	if (defined $response) {
		if (ref($response) eq "ARRAY") {
			$msg->say($_) foreach @$response;
		}
		else {
			$msg->say($response);
		}
		msg_send($msg);
	}
}

sub on_public {
	my $msg = shift;
	return unless defined $msg->message();

	my $response = try_all(
		$msg,
		$msg->message(),
		"public",
		$msg->csnick(),
		$msg->addressed(),
	);
	if (defined $response) {
		if (ref($response) eq "ARRAY") {
			$msg->say($_) foreach @$response;
		}
		else {
			$msg->say($response);
		}
		msg_send($msg);
	}
}

### Helper.  Process a list of commands.
sub try_all {
	my ($obj, $msg, $mode, $nick, $addressed) = @_;
	my $response;

#  warn(
#    scalar(localtime),
#    ": Lag = ",
#    $obj->ts30clirecv() - $obj->ts20svrsend(),
#    " second(s)\n"
#  );

	# Clean up input.
	$msg =~ s/\s+/ /g;
	$msg =~ s/^\s+//;
	$msg =~ s/\s+$//;

	$mode = "private" unless $mode;

	# Try things.
	$response = try_uptime($msg, $mode, $nick, $addressed);
	return $response if defined $response;

	my $net = $obj->network();
	my $chn = $obj->channel();

	my $nk = substr($net, 0, 2);

	unless (exists $tabs{$nk}{$chn}) {

		my $threader = Text::Conversation->new(
			debug         => 1,
			thread_buffer => 30,
		);

		my $tab  = $nb->add( "$nk$chn", -label => "$nk$chn" );

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

		$tabs{$nk}{$chn}  = $tab;
		$trees{$nk}{$chn} = $tree;
		$threaders{$nk}{$chn} = $threader;
	}

	my $threader = $threaders{$nk}{$chn};
	my ($this_id, $referent_id, $debug_text) = $threader->observe($nick, $msg);

	# Rebuild the tree.
	# XXX - I'm throwing brute CPU at the problem of how to manage a
	# tree view.  There's some impedance mismatch between what observe()
	# returns and what TK::Tree expects.

	my $tree = $trees{$nk}{$chn};

	$tree->delete("all");
	foreach my $id ($threader->_id_list()) {
		$tree->add(
			$threader->_id_fully_qualified($id),
			-text => $threader->_id_get_text($id),
		);
	}

	$top->update();
}
