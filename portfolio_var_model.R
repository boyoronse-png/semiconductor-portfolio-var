# SEMICONDUCTOR PORTFOLIO VaR MODEL

# LOAD PACKAGES
library(quantmod)
library(rugarch)
library(xts)

# DOWNLOAD DATA
symbols <- c("ASML", "TSM", "AVGO")

prices_list <- lapply(symbols, function(x) {
  Ad(getSymbols(x, from = "2015-01-01", src = "yahoo", auto.assign = FALSE))
})

prices <- do.call(merge, prices_list)
colnames(prices) <- symbols

# COMPUTE LOG RETURNS
returns <- na.omit(diff(log(prices)))

# CONSTRUCT EQUAL-WEIGHT PORTFOLIO
# KEEP xts DATE INDEX INTACT
weights <- c(1/3, 1/3, 1/3)

portfolio_returns <- xts(
  x = as.numeric(returns %*% weights),
  order.by = index(returns)
)

colnames(portfolio_returns) <- "Portfolio"

# HISTORICAL VaR (95%)
VaR_hist_95 <- quantile(as.numeric(portfolio_returns), 0.05)

# PARAMETRIC VaR (95%)
mu_port <- mean(as.numeric(portfolio_returns))
sigma_port <- sd(as.numeric(portfolio_returns))

VaR_param_95 <- mu_port + sigma_port * qnorm(0.05)

# GARCH(1,1) SPECIFICATION
spec_port <- ugarchspec(
  variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
  mean.model = list(armaOrder = c(0, 0), include.mean = TRUE),
  distribution.model = "norm"
)

# FIT GARCH MODEL
fit_port <- ugarchfit(
  spec = spec_port,
  data = portfolio_returns
)

# EXTRACT CONDITIONAL VOLATILITY
# AND FITTED MEAN WITH CORRECT TIME INDEX
sigma_t <- xts(
  x = as.numeric(sigma(fit_port)),
  order.by = index(portfolio_returns)
)
colnames(sigma_t) <- "Sigma"

mu_t <- xts(
  x = as.numeric(fitted(fit_port)),
  order.by = index(portfolio_returns)
)
colnames(mu_t) <- "Mu"

# GARCH-BASED VaR (95%)
VaR_garch_95 <- xts(
  x = as.numeric(mu_t) + qnorm(0.05) * as.numeric(sigma_t),
  order.by = index(portfolio_returns)
)
colnames(VaR_garch_95) <- "VaR_95"

# PRINT RESULTS
cat("Historical VaR (95%):", VaR_hist_95, "\n")
cat("Parametric VaR (95%):", VaR_param_95, "\n")

# CHECK OBJECTS
cat("\n--- Object Checks ---\n")
print(head(portfolio_returns))
print(head(sigma_t))
print(head(VaR_garch_95))

# CREATE IMAGES FOLDER
if (!dir.exists("images")) dir.create("images")

# SAVE PLOT: PORTFOLIO RETURNS
png("images/portfolio_returns.png", width = 900, height = 600)
plot(
  portfolio_returns,
  main = "Semiconductor Portfolio Log Returns",
  ylab = "Log Return",
  xlab = "Time"
)
dev.off()


# SAVE PLOT: CONDITIONAL VOLATILITY
png("images/portfolio_volatility.png", width = 900, height = 600)
plot(
  sigma_t,
  type = "l",
  main = "Conditional Volatility of Semiconductor Portfolio",
  ylab = "Volatility",
  xlab = "Time"
)
dev.off()


# SAVE PLOT: GARCH-BASED VaR

png("images/portfolio_var_garch.png", width = 900, height = 600)
plot(
  VaR_garch_95,
  type = "l",
  main = "GARCH-Based 95% Value-at-Risk",
  ylab = "VaR",
  xlab = "Time"
)
dev.off()


# VERIFY FILES WERE CREATED PROPERLY

cat("\n--- Files in images folder ---\n")
print(list.files("images"))

cat("\n--- File sizes ---\n")
print(file.info("images/portfolio_returns.png")$size)
print(file.info("images/portfolio_volatility.png")$size)
print(file.info("images/portfolio_var_garch.png")$size)
