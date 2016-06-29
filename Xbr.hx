package ;

@:expose
class Xbr {

	public static inline var wgt1 = 0.129633;
	public static inline var wgt2 = 0.175068;
	public static inline var w1 = -wgt1;
	public static inline var w2 = wgt1 + 0.5;
	public static inline var w3 = -wgt2;
	public static inline var w4 = wgt2 + 0.5;

	static inline function df(a: Float, b: Float) {
		return Math.abs(a - b);
	}

	static inline function clamp(x: Float, floor: Float, ceil: Float) {
		return Math.max(Math.min(x, ceil), floor);
	}

	static inline function clampi(x: Int, floor: Int, ceil: Int) {
		return x < floor ? floor : x > ceil ? ceil : x;
	}

	static inline function matrix4i(): Array<Array<Int>> {
		// Surprisingly, using Uint8Arrays ends up being slower.
		return [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
	}

	static inline function matrix4f(): Array<Array<Float>> {
		return [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
	}

	@:extern static inline function min4i( a: Int, b: Int, c: Int, d: Int ) {
		return ( a < b ) ? 
			(( c < d ) ? (a < c ? a : c) : (a < d ? a : d)):
			(( c < d ) ? (b < c ? b : c) : (b < d ? b : d));
	}	

	@:extern static inline function max4i( a: Int, b: Int, c: Int, d: Int ) {
		return ( a > b ) ? 
			(( c > d ) ? (a > c ? a : c) : (a > d ? a : d)):
			(( c > d ) ? (b > c ? b : c) : (b > d ? b : d));
	}

	/*
		 P1
		 |P0|B |C |P1|         C     F4          |a0|b1|c2|d3|
		 |D |E |F |F4|      B     F     I4       |b0|c1|d2|e3|   |e1|i1|i2|e2|
		 |G |H |I |I4|   P0    E  A  I     P3    |c0|d1|e2|f3|   |e3|i3|i4|e4|
		 |P2|H5|I5|P3|      D     H     I5       |d0|e1|f2|g3|
		 G     H5
		 P2

		 sx, sy
		 -1  -1 | -2  0   (x+y) (x-y)    -3  1  (x+y-1)  (x-y+1)
		 -1   0 | -1 -1                  -2  0
		 -1   1 |  0 -2                  -1 -1
		 -1   2 |  1 -3                   0 -2

		 0  -1 | -1  1   (x+y) (x-y)      ...     ...     ...
		 0   0 |  0  0
		 0   1 |  1 -1
		 0   2 |  2 -2

		 1  -1 |  0  2   ...
		 1   0 |  1  1
		 1   1 |  2  0
		 1   2 |  3 -1

		 2  -1 |  1  3   ...
		 2   0 |  2  2
		 2   1 |  3  1
		 2   2 |  4  0


	 */

	static function diagonal_edge( mat: Array<Array<Float>>, wp: Array<Float> ) {
		var dw1 = wp[0]*(df(mat[0][2], mat[1][1]) + df(mat[1][1], mat[2][0]) +
				df(mat[1][3], mat[2][2]) + df(mat[2][2], mat[3][1])) +
			wp[1]*(df(mat[0][3], mat[1][2]) + df(mat[2][1], mat[3][0])) +
			wp[2]*(df(mat[0][3], mat[2][1]) + df(mat[1][2], mat[3][0])) +
			wp[3]*df(mat[1][2], mat[2][1]) +
			wp[4]*(df(mat[0][2], mat[2][0]) + df(mat[1][3], mat[3][1])) +
			wp[5]*(df(mat[0][1], mat[1][0]) + df(mat[2][3], mat[3][2]));

		var dw2 = wp[0]*(df(mat[0][1], mat[1][2]) + df(mat[1][2], mat[2][3]) +
				df(mat[1][0], mat[2][1]) + df(mat[2][1], mat[3][2])) +
			wp[1]*(df(mat[0][0], mat[1][1]) + df(mat[2][2], mat[3][3])) +
			wp[2]*(df(mat[0][0], mat[2][2]) + df(mat[1][1], mat[3][3])) +
			wp[3]*df(mat[1][1], mat[2][2]) +
			wp[4]*(df(mat[1][0], mat[3][2]) + df(mat[0][1], mat[2][3])) +
			wp[5]*(df(mat[0][2], mat[1][3]) + df(mat[2][0], mat[3][1]));

		return (dw1 - dw2);
	}

	///////////////////////// Super-xBR scaling
	// perform super-xbr (fast shader version) scaling by factor f=2 only.
	public static function superxbr(data, w: Int, h: Int) {
		var f = 2;
		var outw = w*f, outh = h*f;
		var wp = [2.0, 1.0, -1.0, 4.0, -1.0, 1.0];
		var out = new haxe.ds.Vector<Int>(outw * outh);

		// First Pass
		var r = matrix4i();
		var g = matrix4i();
		var b = matrix4i();
		var a = matrix4i();
		var Y = matrix4f();
		var rf = 0.0, gf = 0.0, bf = 0.0, af = 0.0, ri = 0, gi = 0, bi = 0, ai = 0;
		var d_edge = 0.0;
		var min_r_sample = 0, max_r_sample = 0;
		var min_g_sample = 0, max_g_sample = 0;
		var min_b_sample = 0, max_b_sample = 0;
		var min_a_sample = 0, max_a_sample = 0;
		var y = 0;
		
		while( y < outh ) {
			var cy = y / f;
			var x = 0;
		//for ( y in 0...outh ) {
			while ( x < outw ) {	
		//for ( x in 0...outw ) {
				var cx = x / f; // central pixels on original images
				// sample supporting pixels in original image
				for ( sx in -1...3 ) {
					for ( sy in -1...3 ) {
						// clamp pixel locations
						var csy = clamp(sy + cy, 0, h - 1);
						var csx = clamp(sx + cx, 0, w - 1);
						// sample & add weighted components
						var sample = data[Std.int(csy*w + csx)];
						r[sx + 1][sy + 1] = ((sample)>> 0)&0xFF;
						g[sx + 1][sy + 1] = ((sample)>> 8)&0xFF;
						b[sx + 1][sy + 1] = ((sample)>> 16)&0xFF;
						a[sx + 1][sy + 1] = ((sample)>> 24)&0xFF;
						Y[sx + 1][sy + 1] = (0.2126*r[sx + 1][sy + 1] + 0.7152*g[sx + 1][sy + 1] + 0.0722*b[sx + 1][sy + 1]);
					}
				}
				min_r_sample = min4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				min_g_sample = min4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				min_b_sample = min4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				min_a_sample = min4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				max_r_sample = max4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				max_g_sample = max4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				max_b_sample = max4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				max_a_sample = max4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				d_edge = diagonal_edge(Y, wp);
				if (d_edge <= 0) {
					rf = w1*(r[0][3] + r[3][0]) + w2*(r[1][2] + r[2][1]);
					gf = w1*(g[0][3] + g[3][0]) + w2*(g[1][2] + g[2][1]);
					bf = w1*(b[0][3] + b[3][0]) + w2*(b[1][2] + b[2][1]);
					af = w1*(a[0][3] + a[3][0]) + w2*(a[1][2] + a[2][1]);
				} else {
					rf = w1*(r[0][0] + r[3][3]) + w2*(r[1][1] + r[2][2]);
					gf = w1*(g[0][0] + g[3][3]) + w2*(g[1][1] + g[2][2]);
					bf = w1*(b[0][0] + b[3][3]) + w2*(b[1][1] + b[2][2]);
					af = w1*(a[0][0] + a[3][3]) + w2*(a[1][1] + a[2][2]);
				}
				// anti-ringing, clamp.
				rf = clamp(rf, min_r_sample, max_r_sample);
				gf = clamp(gf, min_g_sample, max_g_sample);
				bf = clamp(bf, min_b_sample, max_b_sample);
				af = clamp(af, min_a_sample, max_a_sample);
				var crf = Math.ceil(rf);
				var cgf = Math.ceil(gf);
				var cbf = Math.ceil(bf);
				var caf = Math.ceil(af);
				ri = clampi(crf, 0, 255);
				gi = clampi(cgf, 0, 255);
				bi = clampi(cbf, 0, 255);
				ai = clampi(caf, 0, 255);
				out[y*outw + x] = out[y*outw + x + 1] = out[(y + 1)*outw + x] = data[Std.int(cy*w + cx)];
				out[(y+1)*outw + x+1] = (ai << 24) | (bi << 16) | (gi << 8) | ri;
				x += 2;
			}
			y += 2;
		}

		// Second Pass
		wp[0] = 2.0;
		wp[1] = 0.0;
		wp[2] = 0.0;
		wp[3] = 0.0;
		wp[4] = 0.0;
		wp[5] = 0.0;

		y = 0;
		while ( y < outh ) {
		//for ( y in 0...outh ) {
			var x = 0;
			while ( x < outw ) {
			//for ( x in 0...outw ) {
				// sample supporting pixels in original image
				for ( sx in -1...3 ) {
					for ( sy in -1...3 ) {
						// clamp pixel locations
						var csy = clamp(sx - sy + y, 0, f*h - 1);
						var csx = clamp(sx + sy + x, 0, f*w - 1);
						// sample & add weighted components
						var sample = out[Std.int(csy*outw + csx)];
						r[sx + 1][sy + 1] = ((sample)>> 0)&0xFF;
						g[sx + 1][sy + 1] = ((sample)>> 8)&0xFF;
						b[sx + 1][sy + 1] = ((sample)>> 16)&0xFF;
						a[sx + 1][sy + 1] = ((sample)>> 24)&0xFF;
						Y[sx + 1][sy + 1] = (0.2126*r[sx + 1][sy + 1] + 0.7152*g[sx + 1][sy + 1] + 0.0722*b[sx + 1][sy + 1]);
					}
				}
				min_r_sample = min4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				min_g_sample = min4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				min_b_sample = min4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				min_a_sample = min4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				max_r_sample = max4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				max_g_sample = max4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				max_b_sample = max4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				max_a_sample = max4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				d_edge = diagonal_edge(Y, wp);
				if (d_edge <= 0) {
					rf = w3*(r[0][3] + r[3][0]) + w4*(r[1][2] + r[2][1]);
					gf = w3*(g[0][3] + g[3][0]) + w4*(g[1][2] + g[2][1]);
					bf = w3*(b[0][3] + b[3][0]) + w4*(b[1][2] + b[2][1]);
					af = w3*(a[0][3] + a[3][0]) + w4*(a[1][2] + a[2][1]);
				} else {
					rf = w3*(r[0][0] + r[3][3]) + w4*(r[1][1] + r[2][2]);
					gf = w3*(g[0][0] + g[3][3]) + w4*(g[1][1] + g[2][2]);
					bf = w3*(b[0][0] + b[3][3]) + w4*(b[1][1] + b[2][2]);
					af = w3*(a[0][0] + a[3][3]) + w4*(a[1][1] + a[2][2]);
				}
				// anti-ringing, clamp.
				rf = clamp(rf, min_r_sample, max_r_sample);
				gf = clamp(gf, min_g_sample, max_g_sample);
				bf = clamp(bf, min_b_sample, max_b_sample);
				af = clamp(af, min_a_sample, max_a_sample);
				var crf = Math.ceil(rf);
				var cgf = Math.ceil(gf);
				var cbf = Math.ceil(bf);
				var caf = Math.ceil(af);
				ri = clampi(crf, 0, 255);
				gi = clampi(cgf, 0, 255);
				bi = clampi(cbf, 0, 255);
				ai = clampi(caf, 0, 255);
				out[y*outw + x + 1] = (ai << 24) | (bi << 16) | (gi << 8) | ri;

				for ( sx in -1...3 ) {
					for ( sy in -1...3 ) {
						// clamp pixel locations
						var csy = clamp(sx - sy + 1 + y, 0, f*h - 1);
						var csx = clamp(sx + sy - 1 + x, 0, f*w - 1);
						// sample & add weighted components
						var sample = out[Std.int(csy*outw + csx)];
						r[sx + 1][sy + 1] = ((sample)>> 0)&0xFF;
						g[sx + 1][sy + 1] = ((sample)>> 8)&0xFF;
						b[sx + 1][sy + 1] = ((sample)>> 16)&0xFF;
						a[sx + 1][sy + 1] = ((sample)>> 24)&0xFF;
						Y[sx + 1][sy + 1] = (0.2126*r[sx + 1][sy + 1] + 0.7152*g[sx + 1][sy + 1] + 0.0722*b[sx + 1][sy + 1]);
					}
				}
				d_edge = diagonal_edge(Y, wp);
				if (d_edge <= 0) {
					rf = w3*(r[0][3] + r[3][0]) + w4*(r[1][2] + r[2][1]);
					gf = w3*(g[0][3] + g[3][0]) + w4*(g[1][2] + g[2][1]);
					bf = w3*(b[0][3] + b[3][0]) + w4*(b[1][2] + b[2][1]);
					af = w3*(a[0][3] + a[3][0]) + w4*(a[1][2] + a[2][1]);
				} else {
					rf = w3*(r[0][0] + r[3][3]) + w4*(r[1][1] + r[2][2]);
					gf = w3*(g[0][0] + g[3][3]) + w4*(g[1][1] + g[2][2]);
					bf = w3*(b[0][0] + b[3][3]) + w4*(b[1][1] + b[2][2]);
					af = w3*(a[0][0] + a[3][3]) + w4*(a[1][1] + a[2][2]);
				}
				// anti-ringing, clamp.
				rf = clamp(rf, min_r_sample, max_r_sample);
				gf = clamp(gf, min_g_sample, max_g_sample);
				bf = clamp(bf, min_b_sample, max_b_sample);
				af = clamp(af, min_a_sample, max_a_sample);
				var crf = Math.ceil(rf);
				var cgf = Math.ceil(gf);
				var cbf = Math.ceil(bf);
				var caf = Math.ceil(af);
				ri = clampi(crf, 0, 255);
				gi = clampi(cgf, 0, 255);
				bi = clampi(cbf, 0, 255);
				ai = clampi(caf, 0, 255);
				out[(y+1)*outw + x] = (ai << 24) | (bi << 16) | (gi << 8) | ri;
				x += 2;
			}
			y += 2;
		}

		// Third Pass
		wp[0] =  2.0;
		wp[1] =  1.0;
		wp[2] = -1.0;
		wp[3] =  4.0;
		wp[4] = -1.0;
		wp[5] =  1.0;

		for ( y_ in 0...outh ) {
			y = outh - y_ - 1;
			for ( x_ in 0...outw ) {
				var x = outw - x_ - 1;
				for ( sx in -2...2 ) {
					for ( sy in -2...2 ) {
						// clamp pixel locations
						var csy = clamp(sy + y, 0, f*h - 1);
						var csx = clamp(sx + x, 0, f*w - 1);
						// sample & add weighted components
						var sample = out[Std.int(csy*outw + csx)];
						r[sx + 2][sy + 2] = ((sample)>> 0)&0xFF;
						g[sx + 2][sy + 2] = ((sample)>> 8)&0xFF;
						b[sx + 2][sy + 2] = ((sample)>> 16)&0xFF;
						a[sx + 2][sy + 2] = ((sample)>> 24)&0xFF;
						Y[sx + 2][sy + 2] = (0.2126*r[sx + 2][sy + 2] + 0.7152*g[sx + 2][sy + 2] + 0.0722*b[sx + 2][sy + 2]);
					}
				}
				min_r_sample = min4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				min_g_sample = min4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				min_b_sample = min4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				min_a_sample = min4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				max_r_sample = max4i(r[1][1], r[2][1], r[1][2], r[2][2]);
				max_g_sample = max4i(g[1][1], g[2][1], g[1][2], g[2][2]);
				max_b_sample = max4i(b[1][1], b[2][1], b[1][2], b[2][2]);
				max_a_sample = max4i(a[1][1], a[2][1], a[1][2], a[2][2]);
				var d_edge = diagonal_edge(Y, wp);
				if (d_edge <= 0) {
					rf = w1*(r[0][3] + r[3][0]) + w2*(r[1][2] + r[2][1]);
					gf = w1*(g[0][3] + g[3][0]) + w2*(g[1][2] + g[2][1]);
					bf = w1*(b[0][3] + b[3][0]) + w2*(b[1][2] + b[2][1]);
					af = w1*(a[0][3] + a[3][0]) + w2*(a[1][2] + a[2][1]);
				} else {
					rf = w1*(r[0][0] + r[3][3]) + w2*(r[1][1] + r[2][2]);
					gf = w1*(g[0][0] + g[3][3]) + w2*(g[1][1] + g[2][2]);
					bf = w1*(b[0][0] + b[3][3]) + w2*(b[1][1] + b[2][2]);
					af = w1*(a[0][0] + a[3][3]) + w2*(a[1][1] + a[2][2]);
				}
				// anti-ringing, clamp.
				rf = clamp(rf, min_r_sample, max_r_sample);
				gf = clamp(gf, min_g_sample, max_g_sample);
				bf = clamp(bf, min_b_sample, max_b_sample);
				af = clamp(af, min_a_sample, max_a_sample);
				var crf = Math.ceil(rf);
				var cgf = Math.ceil(gf);
				var cbf = Math.ceil(bf);
				var caf = Math.ceil(af);
				ri = clampi(crf, 0, 255);
				gi = clampi(cgf, 0, 255);
				bi = clampi(cbf, 0, 255);
				ai = clampi(caf, 0, 255);
				out[y*outw + x] = (ai << 24) | (bi << 16) | (gi << 8) | ri;
			}
		}

		return out;
	}
}
