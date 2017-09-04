#include <stdio.h>
#include <time.h>

void allocate_init();
void* allocate(int size);
void deallocate(void* pp);

int main()
{
	double start, end, cost;
	start = clock();
	allocate_init();
	void *p1, *p2, *p3, *p4, *p5;
	p1 = allocate(6);
	printf("p1: %p\n",p1);
	//p5 = allocate(2);
	//printf("p5: %p\n",p5);
	p2 = allocate(513);
	p3 = allocate(40);
	//p4 = allocate(6);
	printf("p2: %p\n",p2);
	printf("p3: %p\n",p3);
	deallocate(p2);
	deallocate(p1);
	deallocate(p3);
	p4 = allocate(800);
	//printf("p3: %p\n",p3);
	printf("p4: %p\n",p4);
	p5 = allocate(2000);
	printf("p5: %p\n",p5);
	end = clock();
	cost = end - start;
	printf("The time is %f\n",cost);
	return 0;
}
