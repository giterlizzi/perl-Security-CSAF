package CSAF::Parser;

use 5.010001;
use strict;
use warnings;

use CSAF;
use CSAF::Util qw(JSON file_read);

use Moo;

has file => (is => 'ro', required => 1);

sub parse {

    my $self = shift;

    Carp::croak qq{File $self->file not found} unless (-e $self->file);

    my $content = file_read($self->file);
    my $json    = eval { JSON->decode($content) };

    Carp::croak qq{Failed to parse $self->file: $@} if ($@);

    Carp::croak qq{Invalid CSAF document} unless (defined $json->{document});

    my $csaf = CSAF->new;

    if (my $document = $json->{document}) {

        $csaf->document->title($document->{title});
        $csaf->document->category($document->{category});
        $csaf->document->csaf_version($document->{csaf_version});
        $csaf->document->lang($document->{lang}) if ($document->{lang});

        if (my $aggregate_severity = $document->{aggregate_severity}) {
            $csaf->document->aggregate_severity(%{$aggregate_severity});
        }

        if (my $distribution = $document->{distribution}) {

            $csaf->document->distribution(%{$distribution});

            if (my $tlp = $distribution->{tlp}) {
                $csaf->document->distribution->tlp(%{$tlp});
            }

        }

        $csaf->document->publisher(%{$document->{publisher}});

        if (my $notes = $document->{notes}) {
            $csaf->document->notes->item(%{$_}) for (@{$notes});
        }

        if (my $references = $document->{references}) {
            $csaf->document->references->item(%{$_}) for (@{$references});
        }

        if (my $tracking = $document->{tracking}) {
            $csaf->document->tracking(%{$tracking});
            $csaf->document->tracking->generator(%{$tracking->{generator}}) if ($tracking->{generator});
            $csaf->document->tracking->generator->engine(%{$tracking->{generator}->{engine}})
                if ($tracking->{generator}->{engine});
            $csaf->document->tracking->revision_history->item(%{$_}) for (@{$tracking->{revision_history}});
        }

        if (my $acknowledgments = $document->{acknowledgments}) {
            $csaf->document->acknowledgments->item(%{$_}) for (@{$acknowledgments});
        }

    }

    if (my $vulnerabilities = $json->{vulnerabilities}) {
        foreach my $vulnerability (@{$vulnerabilities}) {

            my $vuln = $csaf->vulnerabilities->item(cve => $vulnerability->{cve});

            if (my $cwe = $vulnerability->{cwe}) {
                $vuln->cwe(%{$cwe});
            }

            if (my $notes = $vulnerability->{notes}) {
                $vuln->notes->item(%{$_}) for (@{$notes});
            }

            if (my $references = $vulnerability->{references}) {
                $vuln->references->item(%{$_}) for (@{$references});
            }

            if (my $product_status = $vulnerability->{product_status}) {
                $vuln->product_status(%{$product_status});
            }

            if (my $scores = $vulnerability->{scores}) {
                $vuln->scores->item(%{$_}) for (@{$scores});
            }

            if (my $acknowledgments = $vulnerability->{acknowledgments}) {
                $vuln->acknowledgments->item(%{$_}) for (@{$acknowledgments});
            }

            if (my $remediations = $vulnerability->{remediations}) {
                $vuln->remediations->item(%{$_}) for (@{$remediations});
            }

            if (my $threats = $vulnerability->{threats}) {
                $vuln->threats->item(%{$_}) for (@{$threats});
            }

            if (my $involvements = $vulnerability->{involvements}) {
                $vuln->involvements->item(%{$_}) for (@{$involvements});
            }

        }
    }


    if (my $product_tree = $json->{product_tree}) {

        my $csaf_product_tree = $csaf->product_tree;

        if (my $branches = $product_tree->{branches}) {
            branches_walk($branches, $csaf_product_tree);
        }

        if (my $relationships = $product_tree->{relationships}) {
            $csaf_product_tree->relationships->item(%{$_}) for (@{$relationships});
        }
    }

    return $csaf;

}

sub branches_walk {

    my ($branches, $csaf) = @_;

    foreach my $branch (@{$branches}) {
        if (defined $branch->{branches}) {
            branches_walk($branch->{branches}, $csaf->branches->item(%{$branch}));
        }
        else {
            $csaf->branches->item(%{$branch});
        }
    }

}

1;