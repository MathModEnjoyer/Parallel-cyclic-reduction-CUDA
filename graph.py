from matplotlib import pyplot as plt
import numpy as np

u = []

r = None
t = None
duration = None
K = None

lineCount = 0

with open('dArray.txt', 'r') as file:
    for line in file:
        if (lineCount > 0):
            u.append(list(map(float, line.strip().split())))
        else:
            R, I, duration, K = [int(x) for x in line.split()]
            r = np.linspace(0, R, I)
            t = np.linspace(0, duration, K)
        lineCount += 1
    u = np.array(u) 

    fig1 = plt.figure("Figure with const R")

    for iter in range(R+1):
        if round(I / R * iter) >= I:
            plt.plot(t, u[:, I - 1], label = 'r = ' + str(iter) + " I = " + str(I) + " K = " + str(K))
        else:
            plt.plot(t, u[:, round(I / R * iter)], label = 'r = ' + str(iter) + " I = " + str(I) + " K = " + str(K))
    plt.xlabel("t")
    plt.ylabel("u(r,t)")
    plt.legend()

    fig2 = plt.figure("Figure with const T")
    if(duration == 50):
        plt.plot(r, u[0, :], label = 't = ' + str(0) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[round(K / duration), :], label = 't = ' + str(1) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[round(K / duration * 3), :], label = 't = ' + str(3) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[round(K / duration * 7), :], label = 't = ' + str(7) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[round(K / duration * 15), :], label = 't = ' + str(15) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[round(K / duration * 40), :], label = 't = ' + str(40) + " I = " + str(I) + " K = " + str(K))
        plt.plot(r, u[-1, :], label = 't = ' + str(50) + " I = " + str(I) + " K = " + str(K))
    else:
        for iter in range(duration + 1):
            if round(K / duration * iter >= K):
                plt.plot(r, u[-1, :], label = 't = ' + str(iter) + " I = " + str(I) + " K = " + str(K))
            else:
                plt.plot(r, u[round(K / duration * iter), :], label = 't = ' + str(iter) + " I = " + str(I) + " K = " + str(K))
    plt.xlabel("r")
    plt.ylabel("u(r,t)")
    plt.legend()
    plt.show()