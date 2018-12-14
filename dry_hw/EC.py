from collections import namedtuple
from math import inf


class Point(namedtuple('Point', ['x', 'y'])):
    def __str__(self):
        return f"({self.x:d}, {self.y:d})" if self.x is not inf and self.y is not inf else "O"


class EC:
    def __init__(self, a, b, n) -> None:
        """
        This class implements the some operations on the elliptic curve
        of the form y**2 = x**3 + a * x + b
        over the finite field: F_n
        :param a: the coefficient from the elliptic curve equation
        :param b: the coefficient from the elliptic curve equation
        :param n: some prime number which defines the finite field

        o is an extra point in the set of the points that is “at infinity”.
        """
        assert 4 * pow(a, 3) + 27 * b != 0, "The curve is singular"
        self.a = a
        self.b = b
        self.n = n
        self.o = Point(inf, inf)

    def negate(self, x) -> int:
        """
        :param x: number in the finite field F_n
        :return: the negation of x in the finite field F_n
        """
        assert x >=0 and x < self.n, f"x={x:d} is not in the field F_{self.n:d}"
        return self.n - x

    def inverse(self, x) -> int:
        """
        :param x: number in the finite field F_n
        :return: the inverse of x in the finite field F_n
        """
        assert x >= 0 and x < self.n, f"x={x:d} is not in the field F_{self.n:d}"
        for i in range(self.n):
            if (x * i) % self.n == 1:
                return i
        raise ValueError(f"x={x:d} is not invertible in field F_{self.n:d}")

    def get_y(self, x) -> (Point, Point):
        assert x >= 0 and x < self.n, f"x={x:d} is not in the field F_{self.n:d}"
        y_square = (pow(x, 3) + self.a * x + self.b) % self.n
        for i in range(self.n):
            if pow(i, 2, self.n) == y_square:
                return Point(x, i), Point(x, self.negate(i))

    def add(self, p1: Point, p2: Point) -> Point:
        if p1 == self.o:
            return p2
        if p2 == self.o:
            return p1
        if p1 != p2 and p1.x == p2.x:
            return self.o
        if p1 == p2 and p1.y == 0:
            return self.o
        if p1 != p2:
            # calculate slope of the line between p1 and p2
            m = (p2.y - p1.y) * self.inverse((p2.x - p1.x) % self.n) % self.n
        else:
            # calculate slope of the tangent line at p1
            m = ((3 * pow(p1.x, 2) + self.a) * self.inverse((2 * p1.y) % self.n)) % self.n
        n = (p1.y - m * p1.x) % self.n
        return Point((pow(m, 2) - p1.x - p2.x) % self.n, (-pow(m, 3) + m * (p1.x + p2.x) - n) % self.n)

    def mul(self, p1: Point, n) -> Point:
        tmp = p1
        res = self.o
        while n:
            if n & 1:
                res = self.add(res, tmp)
            tmp = self.add(tmp, tmp)
            n = n >> 1
        return res


if __name__ == '__main__':
    ec = EC(-5, 8, 37)
    for i in range(37):
        points = ec.get_y(i)
        if points is not None:
            print(points[0], points[1])
    p = Point(6, 3)
    q = Point(9, 10)
    print("P + Q =", ec.add(p, q))
    print("2P =", ec.mul(p, 2))
    print("3P =", ec.mul(p, 3))
