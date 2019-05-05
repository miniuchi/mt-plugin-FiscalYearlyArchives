package FiscalYearlyArchives::ContentTypeFiscalYearly;
use strict;
use warnings;
use parent 'MT::ArchiveType::ContentTypeYearly';

use FiscalYearlyArchives::FiscalYearly;

sub name { 'ContentType-FiscalYearly' }

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('CONTENTTYPE-FISCAL-YEARLY_ADV'); 
}

sub order { 215 }

sub default_archive_templates {
    return [
        {
            label           => 'fiscal/yyyy/index.html',
            template        => 'fiscal/<$MTArchiveFiscalYear$>/%i',
            default         => 1,
            required_fields => { date_and_time => 1 },
        },
    ];
}

sub dynamic_template {
    'archives/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class                   => 'contenttype-fiscal-yearly-archive',
        datebased_fiscal_yearly_archive => 1,
        archive_template                => 1,
        archive_listing                 => 1,
        datebased_archive               => 1,
        datebased_only_archive          => 1,
        contenttype_archive_listing     => 1,
    };
}

sub archive_title {
    FiscalYearlyArchives::FiscalYearly::archive_title( @_ );
}

sub archive_file {
    FiscalYearlyArchives::FiscalYearly::archive_file( @_ );
}

sub date_range {
    FiscalYearlyArchives::FiscalYearly::date_range( @_ );
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $iter;
    my $sort_order
        = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';

    my $content_type_id = $ctx->stash('content_type')->id;
    my $map             = $obj->_get_preferred_map(
        {   blog_id         => $blog->id,
            content_type_id => $content_type_id,
            map             => $ctx->stash('template_map'),
        }
    );
    my $dt_field_id = $map ? $map->dt_field_id : '';

    require MT::ContentData;
    require MT::ContentFieldIndex;

    my $group_terms
        = $obj->make_archive_group_terms( $blog->id, $dt_field_id, '', '',
        '', $content_type_id );
    my $group_args
        = $obj->make_archive_group_args( 'datebased_only', 'yearly',
        $map, '', '', $args->{lastn}, $order, '' );

    $iter = MT::ContentData->count_group_by( $group_terms, $group_args )
        or return $ctx->error("Couldn't get yearly archive list");

    my @count_groups;
    my $prev_year;
    while ( my @row = $iter->() ) {
        my $ts = sprintf( "%04d%02d%02d000000", $row[1], $row[2], 1 );
        my ( $start, $end ) = start_end_fiscal_year($ts);
        my $year = ts2fiscal($ts);
        if ( defined $prev_year && $prev_year == $year ) {
            $count_groups[-1]->{count} += $row[0];
        }
        else {
            push @count_groups,
              {
                count       => $row[0],
                fiscal_year => $year,
                start       => $start,
                end         => $end,
              };
            $prev_year = $year;
        }
    }

    return sub {
        while ( my $group = shift(@count_groups) ) {
            return ( $group->{count}, %$group );
        }
        undef;
    };
}

1;

