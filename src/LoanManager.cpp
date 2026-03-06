#include "LoanManager.h"
#include "DateUtils.h"
#include <algorithm>
#include <sstream>
#include <iomanip>

LoanManager::LoanManager(Catalog& catalog, std::vector<Member>& members)
    : catalog_(catalog), members_(members)
{}

std::string LoanManager::checkoutBook(const std::string& isbn,
                                      const std::string& member_id,
                                      const std::string& date)
{
    Member* member = findMember(member_id);
    if (!member) return "";

    auto book_opt = catalog_.findByISBN(isbn);
    if (!book_opt.has_value()) return "";
    Book* book = book_opt.value();

    if (!book->isAvailable()) return "";

    if (!member->canBorrow()) return "";

    std::ostringstream oss;
    oss << "L" << std::setfill('0') << std::setw(5) << next_loan_id_++;
    std::string loan_id = oss.str();

    loans_.emplace_back(loan_id, isbn, member_id, date);
    book->borrowCopy();
    member->addLoan(loan_id);

    return loan_id;
}

bool LoanManager::returnBook(const std::string& loan_id,
                             const std::string& return_date)
{
    Loan* loan = findLoan(loan_id);
    if (!loan) return false;
    if (loan->isReturned()) return false;

    loan->markReturned(return_date);

    Member* member = findMember(loan->getMemberID());
    if (member) {
        member->removeLoan(loan_id);
    }

    auto book_opt = catalog_.findByISBN(loan->getBookISBN());
    if (book_opt.has_value()) {
        book_opt.value()->returnCopy();
    }

    return true;
}

bool LoanManager::renewLoan(const std::string& loan_id) {
    Loan* loan = findLoan(loan_id);
    if (!loan) return false;
    if (loan->isReturned()) return false;

    std::string new_due = DateUtils::addDays(loan->getDueDate(), 7);
    std::string isbn      = loan->getBookISBN();
    std::string member_id = loan->getMemberID();
    loan->markReturned(loan->getDueDate());
    loans_.emplace_back(loan_id + "R", isbn, member_id, loan->getDueDate());
    return true;
}

std::vector<Loan> LoanManager::getActiveLoans() const {
    std::vector<Loan> active;
    for (const auto& loan : loans_) {
        if (!loan.isReturned()) {
            active.push_back(loan);
        }
    }
    return active;
}

Loan* LoanManager::findLoan(const std::string& loan_id) {
    for (auto& loan : loans_) {
        if (loan.getLoanID() == loan_id) return &loan;
    }
    return nullptr;
}

Member* LoanManager::findMember(const std::string& member_id) {
    for (auto& m : members_) {
        if (m.getID() == member_id) return &m;
    }
    return nullptr;
}