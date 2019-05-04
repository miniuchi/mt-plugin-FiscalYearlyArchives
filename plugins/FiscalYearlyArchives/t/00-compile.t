use strict;
use warnings;

use Test::More;

use lib qw( lib extlib t/lib plugins/FiscalYearlyArchives/lib );

use_ok 'FiscalYearlyArchives::AuthorFiscalYearly';
use_ok 'FiscalYearlyArchives::CategoryFiscalYearly';
use_ok 'FiscalYearlyArchives::FiscalYearly';
use_ok 'FiscalYearlyArchives::L10N';
use_ok 'FiscalYearlyArchives::L10N::en_us';
use_ok 'FiscalYearlyArchives::L10N::ja';
use_ok 'FiscalYearlyArchives::Util';

done_testing;

~

