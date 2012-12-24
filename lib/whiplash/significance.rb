class Significance
  class << self
    BIGX = 20.0                  
    Z_MAX = 6.0
    LOG_SQRT_PI = 0.5723649429247000870717135
    I_SQRT_PI = 0.5641895835477562869480795

    def call(table)
      1 - pochisq(chisq(table), degrees_of_freedom(table))
    end

    private

    def degrees_of_freedom(table)
      (table.size - 1) * (table.first.size - 1)
    end
     
    def expected_value(table, row, col)
      sum_row = table[row].reduce(&:+)
      sum_col = table.first.size.times.map.reduce(0){ |t, i| t + table[i][col] }
      sum_total = table.size.times.map.reduce(0) do |tr, i|
        tr + table.first.size.times.map.reduce(0){ |tc, j| tc + table[i][j] }
      end
      (sum_row * sum_col) / sum_total.to_f
    end

    def chisq(table)
      table.size.times.map.reduce(0) do |t1, i|
        t1 + table.first.size.times.map.reduce(0) do |t2, j|
          unexpected = table[i][j] - expected_value(table, i, j)
          t2 + ((unexpected ** 2) / expected_value(table, i, j))
        end
      end
    end

    def poz(z)
      if z == 0.0
        x = 0.0
      else
        y = 0.5 * z.abs
        if y >= (Z_MAX * 0.5)
          x = 1.0
        elsif y < 1.0
          w = y * y
          x = ((((((((0.000124818987  * w - 
                      0.001075204047) * w + 0.005198775019) * w - 
                      0.019198292004) * w + 0.059054035642) * w - 
                      0.151968751364) * w + 0.319152932694) * w - 
                      0.531923007300) * w + 0.797884560593) * y * 2.0
        else
          x = (((((((((((((-0.000045255659 * y +
                           0.000152529290) * y - 0.000019538132) * y -
                           0.000676904986) * y + 0.001390604284) * y -
                           0.000794620820) * y - 0.002034254874) * y +
                           0.006549791214) * y - 0.010557625006) * y +
                           0.011630447319) * y - 0.009279453341) * y +
                           0.005353579108) * y - 0.002141268741) * y)
        end
      end
      (z > 0.0) ? ((x + 1.0) * 0.5) : ((1.0 - x) * 0.5)
    end

    def ex(x)
      (x >= -BIGX) ? Math.exp(x) : 0.0
    end

    def pochisq(x, df)
      return 1.0 if (x <= 0.0 or df < 1)
      a = 0.5 * x
      even = not(df & 1)  # is df even
      y = ex(-a) if df > 1
      s = even ? y : (2.0 * poz(-Math.sqrt(x)))
      if (df > 2)
        x = 0.5 * (df - 1.0)
        z = even ? 1.0 : 0.5
        if (a > BIGX)
          e = even ? 0.0 : LOG_SQRT_PI
          c = Math.log(a)
          while (z <= x) do
            e = Math.log(z) + e
            s += ex(c * z - a - e)
            z += 1.0
          end
          return s
        else
          e = even ? 1.0 : (I_SQRT_PI / Math.sqrt(a))
          c = 0.0
          while (z <= x) do
            e = e * float(a / z)
            c = c + e
            z += 1.0
          end
          return c * y + s
        end
      else
        return s
      end
    end
  end
end
