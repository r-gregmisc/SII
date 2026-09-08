# Evaluate difference between smoothed and complete desensitization
Thl <- seq(0, 100, by=1)
Ki <- seq(0, 1, by=0.01)

grid <- expand.grid(Thl=Thl, Ki=Ki)

m <- 1 / (1 + exp(0.075 * (grid$Thl - 66)))
p <- (grid$Thl / 8) - 15
p[p == 0] <- -1e-6

Ki_safe <- pmax(grid$Ki, 1e-10)
K_complete <- ( (Ki_safe)^p + (m)^p ) ^ (1/p)

K_smoothed <- grid$Ki * m

diff <- abs(K_smoothed - K_complete)
max_diff <- max(diff)
print(paste("Max diff:", max_diff))
idx <- which.max(diff)
print(grid[idx,])
print(K_complete[idx])
print(K_smoothed[idx])
