#include <ctime>
#include <iostream>
#define INF 0x3f3f3f3f
using namespace std;
#define random(a, b) ((a) + rand() % ((b) - (a) + 1))
int main() {
    freopen("data.in", "w", stdout);
    srand(time(0));
    int n = random(70, 500);
    n = 500;
    printf("%d\n", n);
    for (int i = 1; i <= n; ++i) {
        for (int j = 1; j <= n; ++j) {
            if(i==j) printf("0.00 ");
            else printf("%.2f ", random(1, 1000) / 100.0);
        }
        puts("");
    }
}