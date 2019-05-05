package FiscalYearlyArchives::ContentTypeAuthorFiscalYearly;
use strict;
use warnings;
use parent 'MT::ArchiveType::ContentTypeAuthorYearly';

sub name { 'ContentType-Author-FiscalYearly' }

sub archive_label {
    my $plugin = MT::Plugin::FiscalYearlyArchives->instance;
    $plugin->translate('CONTENTTYPE-AUTHOR-FISCAL-YEARLY_ADV');
}

sub archive_short_label {
    return MT->translate("AUTHOR-YEARLY_ADV");
}

sub order { 265 }

sub default_archive_templates {
    return [
        {
            label           => 'author/author-display-name/fiscal/yyyy/index.html',
            template        => 'author/%-a/fiscal/<$MTArchiveFiscalYear$>/%f',
            default         => 1,
            required_fields => { date_and_time => 1 },
        },
        {
            label           => 'author/author_display_name/fiscal/yyyy/index.html',
            template        => 'author/%a/fiscal/<$MTArchiveFiscalYear$>/%f',
            required_fields => { date_and_time => 1 },
        },
    ];
}

sub dynamic_template {
    return 'author/<$MTContentAuthorID$>/fiscal/<$MTArchiveFiscalYear$>';
}

sub template_params {
    return {
        archive_class                => 'contenttype-author-fiscal-yearly-archive',
        author_fiscal_yearly_archive => 1,
        archive_template             => 1,
        archive_listing              => 1,
        author_based_archive         => 1,
        datebased_archive            => 1,
        contenttype_archive_listing  => 1,
    };
}

1;

