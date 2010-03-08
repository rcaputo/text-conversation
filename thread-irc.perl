#!/usr/bin/perl

use warnings;
use strict;
use lib qw( lib /home/troc/projects/workbench /home/troc/projects/text-conversation/lib );

use Tk;
use Tk::Tree;
use Tk::Label;
use Tk::Notebook;

use Util::Common qw(try_uptime);
use Util::Backend::POE qw(svc_init svc_run);
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

svc_init("10.0.0.25", 54321);
svc_run();
exit 0;

### Handle IRC messages.

sub on_ctcp_action {
	my $msg = shift;
	return unless defined $msg->message();
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->see(
		$msg->nick(), $msg->ident(), $msg->host(), $msg->message()
	);
	refresh_tree($msg, $threader);
}

sub on_public {
	my $msg = shift;
	return unless defined $msg->message();
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->observe(
		$msg->nick(), $msg->message()
	);
	refresh_tree($msg, $threader);
}

sub on_join {
	my $msg = shift;
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->arrival(
		$msg->nick(), $msg->ident(), $msg->host()
	);
	refresh_tree($msg, $threader);
}

sub on_kick {
	my $msg = shift;
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->departure(
		$msg->nick(), $msg->ident(), $msg->host()
	);
	refresh_tree($msg, $threader);
}

sub on_quit {
	my $msg = shift;

	# TODO - Find all the channels the person is in.  Depart from each
	# individually.

#	my $threader = get_threader($msg);
#	my ($this_id, $referent_id, $debug_text) = $threader->departure(
#		$msg->nick(), $msg->ident(), $msg->host()
#	);
#	refresh_tree($msg, $threader);
}

sub on_part {
	my $msg = shift;
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->departure(
		$msg->nick(), $msg->ident(), $msg->host()
	);
	refresh_tree($msg, $threader);
}

sub on_nick {
	my $msg = shift;
	my $threader = get_threader($msg);
	my ($this_id, $referent_id, $debug_text) = $threader->rename(
		$msg->nick(), $msg->newnick(), $msg->ident(), $msg->host()
	);
	refresh_tree($msg, $threader);
}

sub on_ping { undef }
sub on_mode { undef }

### Helpers.

# Refresh the conversation tree for this network/channel combination.

sub refresh_tree {
	my ($msg, $threader) = @_;
return;
	my $net = $msg->network();
	my $chn = $msg->channel();

	my $tree;
	if (exists $trees{$net}{$chn}) {
		$tree = $trees{$net}{$chn};
	}
	else {
		my $tab  = $nb->add( "$net$chn", -label => "$net$chn" );

		$tree = $tab->Scrolled(
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

		$tabs{$net}{$chn}  = $tab;
		$trees{$net}{$chn} = $tree;
	}

	$tree->delete("all");
	foreach my $id ($threader->_id_list()) {
		$tree->add(
			$threader->_id_fully_qualified($id),
			-text => $threader->_id_get_text($id),
		);
	}

	$top->update();
}

# Return the threader for this network/channel, or create one.

sub get_threader {
	my $msg = shift;

	my $net = $msg->network();
	my $chn = $msg->channel();

	$threaders{$net}{$chn} ||= Text::Conversation->new( debug => 1 );
	return $threaders{$net}{$chn};
}
