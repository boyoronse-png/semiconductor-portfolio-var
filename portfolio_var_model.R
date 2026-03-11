# =========================
# LOAD PACKAGES
# =========================
library(quantmod)
library(rugarch)

# =========================
# DOWNLOAD DATA
# =========================
symbols <- c("ASML", "TSM", "AVGO")

prices_list <- lapply(symbols, function(x) {
  Ad(getSymbols(x, from = "2015-01-01", src = "yahoo", auto.assign = FALSE))
})

prices <- do.call(merge, prices_list)
colnames(prices) <- symbols

# =========================
# COMPUTE LOG RETURNS
# =========================
returns <- na.omit(diff(log(prices)))

# =========================
# EQUAL-WEIGHT PORTFOLIO
# =========================
weights <- c(1/3, 1/3, 1/3)
portfolio_returns <- returns %*% weights
colnames(portfolio_returns) <- "Portfolio"

# =========================
# HISTORICAL VaR (95%)
# =========================
VaR_hist_95 <- quantile(portfolio_returns, 0.05)

# =========================
# PARAMETRIC VaR (95%)
# =========================
mu <- mean(portfolio_returns)
sigma_port <- sd(portfolio_returns)
VaR_param_95 <- mu + sigma_port * qnorm(0.05)

# =========================
# GARCH-BASED VaR
# =========================
spec_port <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
  distribution.model = "norm"
)

fit_port <- ugarchfit(spec = spec_port, data = portfolio_returns)

sigma_t <- sigma(fit_port)
mu_t <- fitted(fit_port)

VaR_garch_95 <- mu_t + qnorm(0.05) * sigma_t

# =========================
# PRINT RESULTS
# =========================
cat("Historical VaR (95%):", VaR_hist_95, "\n")
cat("Parametric VaR (95%):", VaR_param_95, "\n")

# =========================
# SAVE PLOTS
# =========================
if (!dir.exists("images")) dir.create("images")

png("images/portfolio_returns.png", width = 900, height = 600)
plot(portfolio_returns, main = "Semiconductor Portfolio Log Returns")
dev.off()

png("images/portfolio_volatility.png", width = 900, height = 600)
plot(sigma_t, main = "Conditional Volatility of Semiconductor Portfolio")
dev.off()

png("images/portfolio_var_garch.png", width = 900, height = 600)
plot(VaR_garch_95, main = "GARCH-Based 95% Value-at-Risk")
dev.off()