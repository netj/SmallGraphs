#include "smallgraph.h"
#include <iostream>

int main(void) {
    SmallGraphQuery q;

    SmallGraphWalk *walk = new SmallGraphWalk();
    walk->push_back(1);
    walk->push_back(2);
    walk->push_back(3);
    q.push_back(walk);

    SmallGraphWalk *walk2 = new SmallGraphWalk();
    walk2->push_back(4);
    walk2->push_back(5);
    walk2->push_back(6);
    walk2->push_back(7);
    walk2->push_back(8);
    q.push_back(walk2);

    Matches ms;
    Match *m = new Match(q);
    ms.push_back(m);
    ms.back()->extendWithNode(4, 40, &ms);
    ms.back()->extendWithNode(1, 10, &ms);
    ms.back()->extendWithEdge(5, 50, &ms);
    ms.back()->extendWithNode(6, 60, &ms);
    ms.back()->extendWithEdge(7, 70, &ms);
    ms.back()->extendWithEdge(2, 20, &ms);
    ms.back()->extendWithNode(8, 80, &ms);
    ms.back()->extendWithNode(3, 30, &ms);

    cout << "# Matching Steps = " << ms.size() <<endl;
    for (Matches::iterator it = ms.begin(); it != ms.end(); it++) {
        (*it)->show(cout);
    }

    return 0;
}
