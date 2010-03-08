#!/usr/bin/perl

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

WriteMakefile(
	NAME         => 'Text::Conversation',
	AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
	ABSTRACT     => 'Turn a conversation into threads, one line at a time.',
	LICENSE      => 'perl',
	VERSION_FROM => 'lib/Text/Conversation.pm',
	META_ADD     => {
		resources  => {
			license    => 'http://dev.perl.org/licenses/',
			repository => 'http://github.com/rcaputo/text-conversation'
		},
	},
	PREREQ_PM    => {
		'Lingua::Stem::Snowball'  =>  0.7,
		'Lingua::StopWords::EN'   =>  0.0,
		'String::Approx'          =>  3.23,
	},
	dist         => {
		COMPRESS   => 'gzip -9f',
		SUFFIX     => 'gz',
		PREOP      => (
			'git-log.pl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
		),
	},
);
