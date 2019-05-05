package FiscalYearlyArchives::ContentTypeCategoryFiscalYearly;
use strict;
use warnings;
use parent 'MT::ArchiveType::ContentTypeCategoryYearly';

use MT::Util qw( dirify );
use FiscalYearlyArchives::Util
  qw( fiscal_start_month ts2fiscal start_end_fiscal_year );

use FiscalYearlyArchives::ContentTypeFiscalYearly;
use FiscalYearlyArchives::CategoryFiscalYearly;

sub name { 'ContentType-Category-FiscalYearly' }

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('CONTENTTYPE-CATEGORY-FISCAL-YEARLY_ADV');
}

sub archive_short_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    return $plugin->translate("CATEGORY-FISCAL-YEARLY_ADV");
}

sub order { 315 }

sub dynamic_template {
    return 'category/<$MTCategoryID$>/fiscal/<$MTArchiveFiscalYear$>';
}

sub default_archive_templates {
    return [
        {
            label           => 'category/sub-category/fiscal/yyyy/index.html',
            template        => '%-c/fiscal/<$MTArchiveFiscalYear$>/%i',
            default         => 1,
            required_fields => { category => 1, date_and_time => 1 }
        },
        {
            label           => 'category/sub_category/fiscal/yyyy/index.html',
            template        => '%c/fiscal/<$MTArchiveFiscalYear$>/%i',
            required_fields => { category => 1, date_and_time => 1 }
        },
    ];
}

sub template_params {
    return {
        archive_class => "contenttype-category-fiscal-yearly-archive",
        category_fiscal_yearly_archive => 1,
        archive_template               => 1,
        archive_listing                => 1,
        datebased_archive              => 1,
        category_based_archive         => 1,
        category_set_based_archive     => 1,
        contenttype_archive_listing    => 1,
    };
}

sub archive_title {
    FiscalYearlyArchives::CategoryFiscalYearly::archive_title(@_);
}

sub archive_file {
    my $archiver = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp    = $param{Timestamp};
    my $file_tmpl    = $param{Template};
    my $blog         = $ctx->{__stash}{blog};
    my $cat          = $ctx->{__stash}{cat} || $ctx->{__stash}{category};
    my $content_data = $ctx->{__stash}{content};
    my $file;

    my $this_cat = $archiver->_get_this_cat( $cat, $content_data );

    if ($file_tmpl) {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} ) =
          start_end_fiscal_year($timestamp);
        $ctx->stash( 'archive_category', $this_cat );
        $ctx->{inside_mt_categories} = 1;
        $ctx->{__stash}{category} = $this_cat;
    }
    else {
        if ( !$this_cat ) {
            return "";
        }
        my $label = '';
        $label = dirify( $this_cat->label );
        if ( $label !~ /\w/ ) {
            $label = $this_cat ? "cat" . $this_cat->id : "";
        }
        my $year = ts2fiscal($timestamp);
        $file = sprintf( "%s/%04d/index", $this_cat->category_path, $year );
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
    my $cat_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc'                 : 'desc';
    my $limit = exists $args->{lastn}       ? delete $args->{lastn} : undef;
    my $tmpl  = $ctx->stash('template');
    my $cat   = $ctx->stash('archive_category') || $ctx->stash('category');
    my @data  = ();
    my $count = 0;

    my $content_type_id = $ctx->stash('content_type')->id;
    my $map             = $obj->_get_preferred_map(
        {
            blog_id         => $blog->id,
            content_type_id => $content_type_id,
            map             => $ctx->stash('template_map'),
        }
    );
    my $cat_field_id = $map ? $map->cat_field_id : '';
    my $dt_field_id  = $map ? $map->dt_field_id  : '';

    require MT::ContentData;
    require MT::ContentFieldIndex;

    my $loop_sub = sub {
        my ( $c, $cat_field_id ) = @_;

        my $group_terms =
          $obj->make_archive_group_terms( $blog->id, $dt_field_id, '', '', '',
            $content_type_id );
        my $group_args = $obj->make_archive_group_args( 'category', 'yearly',
            $map, '', '', $args->{lastn}, $order, $c, $cat_field_id );

        my $cd_iter =
          MT::ContentData->count_group_by( $group_terms, $group_args )
          or return $ctx->error("Couldn't get yearly archive list");

        my $prev_year;
        while ( my @row = $cd_iter->() ) {
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
                    category    => $c,
                  };
                $prev_year = $year;
            }
            return $count + 1
              if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
    };

    if ($cat) {
        $loop_sub->($cat);
    }

    else {
        require MT::Category;
        my $iter = MT::Category->load_iter(
            {
                blog_id => $blog->id,
                (
                    $args->{category_set_id}
                    ? ( category_set_id => $args->{category_set_id} )
                    : ( category_set_id => { op => '!=', value => 0 } )
                )
            },
            { 'sort' => 'label', direction => $cat_order }
        );
        while ( my $category = $iter->() ) {
            my $last;
            if ( $map && $map->cat_field_id ) {
                $loop_sub->( $category, $map->cat_field_id );
                $last++ if ( defined($limit) && $count == $limit );
            }
            else {
                my $set_id =
                  $args->{category_set_id} || $category->category_set_id;
                my @fields = MT->model('content_field')
                  ->load( { related_cat_set_id => $set_id } );
                foreach my $field (@fields) {
                    $loop_sub->( $category, $field->id );
                    $last++ if ( defined($limit) && $count == $limit );
                }
            }
            last if $last;
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
    my $cat   = $param->{category} || $ctx->stash('archive_category');
    my $limit = $param->{limit};
    $obj->dated_category_contents( $ctx, $obj->name, $cat, $ts,
        $limit, $content_type_id );
}

1;

