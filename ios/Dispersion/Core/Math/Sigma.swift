// Port of app/src/lib/sigma.ts. Sample dispersion estimation from logged shots.

import Foundation

public struct ShotXY: Hashable, Sendable {
    public var lat: Double
    public var long: Double

    public init(lat: Double, long: Double) {
        self.lat = lat
        self.long = long
    }
}

public struct DispersionStats: Hashable, Sendable {
    public var carrySd: Double
    public var lateralSd: Double
    public var longBias: Double
    public var latBias: Double
    public var n: Int

    public static let empty = DispersionStats(carrySd: 0, lateralSd: 0, longBias: 0, latBias: 0, n: 0)
}

public enum Sigma {
    /// Sample mean + sample stddev (n-1 denominator) for a small set of shots.
    public static func dispersionFromShots(_ shots: [ShotXY]) -> DispersionStats {
        let n = shots.count
        guard n >= 1 else { return .empty }
        let sumLong = shots.reduce(0.0) { $0 + $1.long }
        let sumLat = shots.reduce(0.0) { $0 + $1.lat }
        let meanLong = sumLong / Double(n)
        let meanLat = sumLat / Double(n)
        guard n >= 2 else {
            return DispersionStats(
                carrySd: 0,
                lateralSd: 0,
                longBias: meanLong,
                latBias: meanLat,
                n: n
            )
        }
        var ssLong = 0.0
        var ssLat = 0.0
        for s in shots {
            let dl = s.long - meanLong
            let dx = s.lat - meanLat
            ssLong += dl * dl
            ssLat += dx * dx
        }
        let varLong = ssLong / Double(n - 1)
        let varLat = ssLat / Double(n - 1)
        return DispersionStats(
            carrySd: sqrt(varLong),
            lateralSd: sqrt(varLat),
            longBias: meanLong,
            latBias: meanLat,
            n: n
        )
    }

    /// 95% CI half-width for a sample stddev, assuming normal data.
    /// Uses the chi-square distribution (n-1 dof). Mirrors `sampleSdCi` in TS.
    public static func sampleSdCi(sd: Double, n: Int) -> (lower: Double, upper: Double)? {
        guard n >= 2, sd > 0 else { return nil }
        // Approximate chi² critical values for two-tailed 95% CI.
        // Use a small lookup with linear interp for n in [2, 60]; beyond, use
        // Wilson-Hilferty approximation.
        let dof = Double(n - 1)
        let lowerChi2 = chi2Quantile(p: 0.025, dof: dof)
        let upperChi2 = chi2Quantile(p: 0.975, dof: dof)
        let lower = sd * sqrt(dof / upperChi2)
        let upper = sd * sqrt(dof / lowerChi2)
        return (lower, upper)
    }

    /// Wilson-Hilferty chi² quantile: good accuracy for dof ≥ ~5.
    private static func chi2Quantile(p: Double, dof: Double) -> Double {
        let z = normalQuantile(p: p)
        let h = 2.0 / (9.0 * dof)
        let v = 1 - h + z * sqrt(h)
        return dof * v * v * v
    }

    /// Inverse CDF of standard normal — Beasley-Springer-Moro approximation.
    private static func normalQuantile(p: Double) -> Double {
        // Coefficients from Peter Acklam's algorithm.
        let a: [Double] = [
            -3.969683028665376e+01,
             2.209460984245205e+02,
            -2.759285104469687e+02,
             1.383577518672690e+02,
            -3.066479806614716e+01,
             2.506628277459239e+00,
        ]
        let b: [Double] = [
            -5.447609879822406e+01,
             1.615858368580409e+02,
            -1.556989798598866e+02,
             6.680131188771972e+01,
            -1.328068155288572e+01,
        ]
        let c: [Double] = [
            -7.784894002430293e-03,
            -3.223964580411365e-01,
            -2.400758277161838e+00,
            -2.549732539343734e+00,
             4.374664141464968e+00,
             2.938163982698783e+00,
        ]
        let d: [Double] = [
             7.784695709041462e-03,
             3.224671290700398e-01,
             2.445134137142996e+00,
             3.754408661907416e+00,
        ]
        let pLow = 0.02425
        let pHigh = 1.0 - pLow
        var q: Double
        var r: Double
        if p < pLow {
            q = sqrt(-2 * log(p))
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p <= pHigh {
            q = p - 0.5
            r = q * q
            return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
                / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        } else {
            q = sqrt(-2 * log(1 - p))
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
    }
}
