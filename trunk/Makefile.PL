#!/usr/bin/perl
# $Id$

use ExtUtils::MakeMaker;

# Touch CHANGES so it exists.
open(CHANGES, ">>CHANGES") and close CHANGES;

WriteMakefile(
  NAME         => 'Text::Conversation',
  AUTHOR       => 'Rocco Caputo <rcaputo@cpan.org>',
  ABSTRACT     => 'Turn a conversation into threads, one line at a time.',
  VERSION_FROM => 'lib/Text/Conversation.pm',

  PREREQ_PM    => {
		'Lingua::Stem::Snowball'  =>  0.7,
		'Lingua::StopWords::EN'   =>  0.0,
		'String::Approx'          =>  3.23,
	},
  dist         => {
    COMPRESS   => 'gzip -9f',
    SUFFIX     => 'gz',
    PREOP      => (
      'cvs-log.perl | tee ./$(DISTNAME)-$(VERSION)/CHANGES > ./CHANGES'
    ),
  },
);
