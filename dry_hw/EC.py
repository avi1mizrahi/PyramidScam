

class EC():
    def __init__(self, a, b, q):
        self.a = a
        self.b = b
        self.q = q

    def find_y(self, x):
        y_square = (pow(x, 3) + self.a * x + self.b) % self.q
        y = []
        for i in range(self.q):
            if pow(i, 2, self.q) == y_square:
                return i, self.neg(i)

    def neg(self, x):
        return self.q - x



if __name__ == '__main__':
    ec = EC(-5,8,37)
    for i in range(37):
        print(str(i) + ":" + str(ec.find_y(i)))