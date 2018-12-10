def extended_gcd(a, b):
    """ ----- THIS FUNCTION WAS TAKEN FROM THE INTERNET -----
    Returns a tuple (r, i, j) such that r = gcd(a, b) = ia + jb
    """
    # r = gcd(a,b) i = multiplicitive inverse of a mod b
    #      or      j = multiplicitive inverse of b mod a
    # Neg return values for i or j are made positive mod b or a respectively
    # Iterateive Version is faster and uses much less stack space
    x = 0
    y = 1
    lx = 1
    ly = 0
    oa = a  # Remember original a/b to remove
    ob = b  # negative values from return results
    while b != 0:
        q = a // b
        (a, b) = (b, a % b)
        (x, lx) = ((lx - (q * x)), x)
        (y, ly) = ((ly - (q * y)), y)
    if lx < 0:
        lx += ob  # If neg wrap modulo orignal b
    if ly < 0:
        ly += oa  # If neg wrap modulo orignal a
    return a, lx, ly  # Return only positive values


def multiplicative_inverse_modulo(x, n):
    (divider, inv, _) = extended_gcd(x, n)

    if divider != 1:
        raise ValueError(f"x={x:d} n={n:d} are not co-prime")

    return inv


'''
Our code starts from here
'''


class PublicKey:

    def __init__(self, n, e) -> None:
        self.e = e
        self.n = n

    def __str__(self) -> str:
        return f"PublicKey:(n={ self.n }, e={ self.e })"


class PrivateKey:

    def __init__(self, d) -> None:
        self.d = d

    def __str__(self) -> str:
        return f"PrivateKey:(d={ self.d })"


class RSA:
    def __init__(self, p, q, e) -> None:
        self.public_key = PublicKey(p * q, e)
        phi = (p - 1) * (q - 1)
        self.private_key = PrivateKey(multiplicative_inverse_modulo(e, phi))

    def sign(self, m):
        return pow(m, self.private_key.d, self.public_key.n)

    def verify(self, m, signature) -> bool:
        return pow(signature, self.public_key.e, self.public_key.n) == m


if __name__ == '__main__':
    rsa = RSA(p=4973, q=5347, e=1547)
    print(rsa.public_key, rsa.private_key, sep='\n')

    message = 122
    signature = rsa.sign(message)
    verified = rsa.verify(message, signature)
    print(f"message={ message }; signature={ signature }; verified={ verified }")
