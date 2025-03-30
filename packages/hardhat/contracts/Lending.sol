// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./RWAOracle.sol";

contract LendingPoolRealEstate is ERC20 {
    struct Loan {
        address borrower;
        address token;
        uint256 totalAmount;
        uint256 monthlyAmount;
        uint256 collateral;
        uint256 lastWithdrawTime;
        uint256 monthsLeft;
        bool isActive;
    }

    address public admin;
    RWAOracle public oracle;
    mapping(uint256 => Loan) public loans;
    uint256 public loanCounter;

    event LoanCreated(uint256 indexed loanId, address borrower, uint256 totalAmount, uint256 collateral);
    event MonthlyLoanWithdrawn(uint256 indexed loanId, uint256 amount, uint256 monthsLeft);
    event LoanRepaid(uint256 indexed loanId);
    event LoanLiquidated(uint256 indexed loanId);

    constructor(address _oracle, string memory name, string memory symbol) ERC20(name, symbol) {
        admin = msg.sender;
        oracle = RWAOracle(_oracle);
    }

    function createLoan(address token, uint256 totalAmount, uint256 collateral, uint256 months) external {
        require(oracle.getPrice(token) > 0, "Token not supported");

        uint256 collateralValue = collateral * oracle.getPrice(token);
        require(collateralValue >= totalAmount, "Insufficient collateral");
        require(months > 0, "Loan period must be at least one month");

        uint256 monthlyAmount = totalAmount / months;

        ERC20(token).transferFrom(msg.sender, address(this), collateral);

        loans[loanCounter] = Loan({
            borrower: msg.sender,
            token: token,
            totalAmount: totalAmount,
            monthlyAmount: monthlyAmount,
            collateral: collateral,
            // Set initial withdrawal time to allow immediate first withdrawal
            lastWithdrawTime: block.timestamp - 30 days,
            monthsLeft: months,
            isActive: true
        });

        emit LoanCreated(loanCounter, msg.sender, totalAmount, collateral);
        loanCounter++;
    }

    function withdrawMonthlyLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");
        require(msg.sender == loan.borrower, "Only borrower can withdraw");
        require(loan.monthsLeft > 0, "No remaining monthly payouts");

        // Allow first withdrawal immediately, subsequent withdrawals monthly
        if (loan.monthsLeft < loan.totalAmount / loan.monthlyAmount) { // Check if not first withdrawal
            require(block.timestamp >= loan.lastWithdrawTime + 30 days, "Withdrawal only allowed monthly");
        }

        ERC20(loan.token).transfer(loan.borrower, loan.monthlyAmount);
        
        loan.lastWithdrawTime = block.timestamp;
        loan.monthsLeft--;

        emit MonthlyLoanWithdrawn(loanId, loan.monthlyAmount, loan.monthsLeft);

        if (loan.monthsLeft == 0) {
            loan.isActive = false;
            emit LoanRepaid(loanId);
        }
    }

    function liquidateLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");

        uint256 collateralValue = loan.collateral * oracle.getPrice(loan.token);
        require(collateralValue < loan.totalAmount, "Collateral value is sufficient");

        loan.isActive = false;
        emit LoanLiquidated(loanId);
    }
}