from collections import namedtuple
from math import inf

Point = namedtuple('Point', ['x', 'y'], verbose=True)

class EC():
    def __init__(self, a, b, n):
        if 4 * pow(a, 3) + 27 * b == 0:
            raise ValueError(f"The curve is singular")
        self.a = a
        self.b = b
        self.n = n
        self.zero = Point(inf, inf)

    def find_y(self, x):
        y_square = (pow(x, 3) + self.a * x + self.b) % self.n
        for i in range(self.n):
            if pow(i, 2, self.n) == y_square:
                return Point(x, i), Point(x, self.neg(i))

    def neg(self, x):
        return self.n - x

    def inv(self, x):
        for i in range(self.n):
            if (x * i) % self.n:
                return i
        raise ValueError(f"x={x:d} is not invertible in field F_{self.n:d}")

    def add(self, p1 : Point, p2 : Point):
        if p1 == self.zero:
            return p2
        if p2 == self.zero:
            return p1
        if p1 != p2 and p1.x == p2.x:
            return self.zero
        if p1 == p2 and p1.y == 0:
            return self.zero
        if p1 != p2:
            # calculate line between p and q
            m = (p2.y - p1.y) * self.inv(p2.x - p1.x) % self.n
        else:
            # calculate the tangent line
            m = (3 * pow(p1.x, 2) + self.a) * self.inv(2 * p1.y) % self.n
        n = (p1.y - m * p1.x) % self.n
        return Point((pow(m, 2) - p1.x - p2.x) % self.n, (-pow(m, 3) + m * (p1.x + p2.x) - n) % self.n)

    def mul(self, p, n):
        # TODO: do it in log time
        tmp = self.zero
        for i in range(n):
           tmp = self.add(tmp, p)
        return tmp

if __name__ == '__main__':
    ec = EC(-5,8,37)
    for i in range(37):
        points = ec.find_y(i)
        if points is not None:
            print(points[0], points[1])
    p = Point(6, 3)
    q = Point(9, 10)
    print(ec.add(p, q))
    print(ec.mul(p, 2))
    print(ec.mul(p, 3))