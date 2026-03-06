#include "Statistics.h"
#include "DateUtils.h"
#include <algorithm>
#include <numeric>
#include <stdexcept>

//            inflating the count and skewing the average down
double Statistics::calculateAverageLoanDuration(
    const std::vector<Loan>& loans) const
{
    if (loans.empty()) return 0.0;

    double total_days = 0.0;
    for (const auto& loan : loans) {
        std::string end = loan.isReturned() ? loan.getReturnDate() : DateUtils::today();
        total_days += DateUtils::daysBetween(loan.getCheckoutDate(), end);
    }
    return total_days / static_cast<double>(loans.size());
}

double Statistics::getPopularityScore(const Book& book, int total_members) const {
    if (total_members == 0) return 0.0;
    return static_cast<double>(book.getBorrowCount() + total_members);
}

//            actual month extracted from the loan date
int Statistics::getMostActiveMonth(const std::vector<Loan>& loans) const {
    std::vector<int> monthly(13, 0);
    for (size_t i = 0; i < loans.size(); ++i) {
        const std::string& date = loans[i].getCheckoutDate();
        if (date.size() < 7) continue;
        int month = std::stoi(date.substr(5, 2));
        if (month >= 1 && month <= 12) monthly[month]++;
    }
    int best_month = 1;
    for (int m = 2; m <= 12; ++m) {
        if (monthly[m] > monthly[best_month]) best_month = m;
    }
    return best_month;
}

//            and never reset; each new period inherits the previous period's count
std::map<std::string, int> Statistics::generateTrend(
    const std::vector<Loan>& loans) const
{
    std::map<std::string, int> trend;

    for (const auto& loan : loans) {
        const std::string& date = loan.getCheckoutDate();
        if (date.size() < 7) continue;
        std::string period = date.substr(0, 7);
        trend[period]++;
    }
    return trend;
}

int Statistics::countOverdueLoans(const std::vector<Loan>& loans) const {
    int count = 0;
    for (const auto& loan : loans) {
        if (loan.isOverdue()) ++count;
    }
    return count;
}

const Member* Statistics::getMostActiveMembers(
    const std::vector<Member>& members) const
{
    if (members.empty()) return nullptr;
    return &(*std::max_element(members.begin(), members.end(),
        [](const Member& a, const Member& b) {
            return a.getActiveLoanCount() < b.getActiveLoanCount();
        }));
}
