package FiscalYearlyArchives::ContentTypeAuthorFiscalYearly;
use strict;
use warnings;
use parent 'MT::ArchiveType::ContentTypeAuthorYearly';

use FiscalYearlyArchives::Util
  qw( fiscal_start_month ts2fiscal start_end_fiscal_year );
use MT::Util qw( dirify );

use FiscalYearlyArchives::AuthorFiscalYearly;
use FiscalYearlyArchives::ContentTypeFiscalYearly;

sub name { 'ContentType-Author-FiscalYearly' }

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('CONTENTTYPE-AUTHOR-FISCAL-YEARLY_ADV');
}

sub archive_short_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    return $plugin->translate("AUTHOR-FISCAL-YEARLY_ADV");
}

sub order { 265 }

sub default_archive_templates {
    return [
        {
            label    => 'author/author-display-name/fiscal/yyyy/index.html',
            template => 'author/%-a/fiscal/<$MTArchiveFiscalYear$>/%f',
            default  => 1,
            required_fields => { date_and_time => 1 },
        },
        {
            label    => 'author/author_display_name/fiscal/yyyy/index.html',
            template => 'author/%a/fiscal/<$MTArchiveFiscalYear$>/%f',
            required_fields => { date_and_time => 1 },
        },
    ];
}

sub dynamic_template {
    return 'author/<$MTContentAuthorID$>/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class => 'contenttype-author-fiscal-yearly-archive',
        author_fiscal_yearly_archive => 1,
        archive_template             => 1,
        archive_listing              => 1,
        author_based_archive         => 1,
        datebased_archive            => 1,
        contenttype_archive_listing  => 1,
    };
}

sub archive_title {
    FiscalYearlyArchives::AuthorFiscalYearly::archive_title(@_);
}

sub archive_file {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp = $param{Timestamp};
    my $file_tmpl = $param{Template};
    my $author    = $ctx->{__stash}{author};
    my $content   = $ctx->{__stash}{content};
    my $file;
    my $this_author =
      $author ? $author : ( $content ? $content->author : undef );
    return "" unless $this_author;
    my $name = dirify( $this_author->nickname );

    if ( $name eq '' || !$file_tmpl ) {
        $name = 'author' . $this_author->id if $name !~ /\w/;
        my $year = ts2fiscal($timestamp);
        $file = sprintf( "%s/%04d/index", $name, $year );
    }
    else {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
          start_end_fiscal_year($timestamp);
    }
    $file;
}

sub date_range {
    FiscalYearlyArchives::ContentTypeFiscalYearly::date_range(@_);
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $sort_order =
      ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $auth_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    my @data  = ();
    my $count = 0;

    my $author = $ctx->stash('author');

    my $content_type_id = $ctx->stash('content_type')->id;
    my $map             = $obj->_get_preferred_map(
        {
            blog_id         => $blog->id,
            content_type_id => $content_type_id,
            map             => $ctx->stash('template_map'),
        }
    );
    my $dt_field_id = $map ? $map->dt_field_id : '';

    require MT::ContentData;
    require MT::ContentFieldIndex;

    my $loop_sub = sub {
        my $auth = shift;

        my $group_terms =
          $obj->make_archive_group_terms( $blog->id, $dt_field_id, '', '',
            $auth->id, $content_type_id );
        my $group_args = $obj->make_archive_group_args( 'author', 'yearly',
            $map, '', '', $args->{lastn}, $order, '' );

        my $count_iter =
          MT::ContentData->count_group_by( $group_terms, $group_args )
          or return $ctx->error("Couldn't get monthly archive list");

        my $prev_year;
        while ( my @row = $count_iter->() ) {
            my $ts = sprintf( "%04d%02d%02d000000", $row[1], $row[2], 1 );
            my ( $start, $end ) = start_end_fiscal_year($ts);
            my $year = ts2fiscal($ts);
            if ( defined $prev_year && $prev_year == $year ) {
                $data[-1]->{count} += $row[0];
            }
            else {
                push @data,
                  {
                    count       => $row[0],
                    fiscal_year => $year,
                    start       => $start,
                    end         => $end,
                    author      => $auth,
                  };
                $prev_year = $year;
            }
            return $count + 1
              if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
        return $count;
    };

    # Count entry by author
    if ($author) {
        $loop_sub->($author);
    }
    else {
        # load authors
        require MT::Author;
        my $iter;
        $iter = MT::Author->load_iter(
            undef,
            {
                sort      => 'name',
                direction => $auth_order,
                join      => [
                    'MT::ContentData',
                    'author_id',
                    {
                        status  => MT::ContentStatus::RELEASE(),
                        blog_id => $blog->id
                    },
                    { unique => 1 }
                ]
            }
        );

        while ( my $a = $iter->() ) {
            $loop_sub->($a);
            last if ( defined($limit) && $count == $limit );
        }
    }

    return sub {
        while ( my $group = shift(@data) ) {
            return ( $group->{count}, %$group );
        }
        undef;
    };
}

sub archive_group_contents {
    my $obj = shift;
    my ( $ctx, $param, $content_type_id ) = @_;
    my $ts =
      $param->{fiscal_year}
      ? sprintf( "%04d%02d%02d000000",
        $param->{fiscal_year}, fiscal_start_month(), 1 )
      : $ctx->stash('current_timestamp');
    my $author = $param->{author} || $ctx->stash('author');
    my $limit  = $param->{limit};
    $obj->dated_author_contents( $ctx, $obj->name, $author,
        $ts, $limit, $content_type_id );
}

1;

