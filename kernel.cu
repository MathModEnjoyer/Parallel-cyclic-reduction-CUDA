#include <iostream>
#include <fstream>
#include <chrono>
#include <cuda_runtime.h>

using namespace std;

__global__ void forwardStepKernel(double* c, double* a, double* b, double* d, int a_size, 
	int a_size_next, int c_size, int a_start_id, int c_start_id, int k)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx < a_size_next)
	{
		int id_prev = a_start_id + idx * 2 + 1;       // предыдущие коэффициенты
		int id_prev_с = c_start_id + idx * 2 + 1;     //
		int id_cur = a_start_id + a_size + idx;   // текущие коэффициенты
		int id_cur_c = c_start_id + c_size + idx; //

		double repeat_coef_1 = c[id_prev_с - 1] / a[id_prev - 1];
		double repeat_coef_2 = b[id_prev_с] / a[id_prev + 1];
		if (k == 0)
		{
			if (idx > 0) c[id_cur_c - 1] = -repeat_coef_1 * c[id_prev_с - 2];

			a[id_cur] = a[id_prev] - repeat_coef_1 * b[id_prev_с - 1] - repeat_coef_2 * c[id_prev_с];

			if (idx < a_size_next - 1) b[id_cur_c] = -repeat_coef_2 * b[id_prev_с + 1];
		}
		d[id_cur] = d[id_prev] - repeat_coef_1 * d[id_prev - 1] - repeat_coef_2 * d[id_prev + 1];
	}
}

__global__ void backStepKernel(double* c, double* a, double* b, double* d, int a_size, 
	int c_size, int a_start_id, int c_start_id, int a_sum, int i, int q_input, int eq_use_count, int I)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (i < q_input - 1 && idx < eq_use_count)
	{
		int shift = 1 << i;
		int id_cur = a_sum + shift + idx * (shift << 1) - 1;
		int j_2 = idx * 2;
		if (idx > 0 && idx < eq_use_count - 1)
		{
			d[id_cur] = (d[a_start_id + j_2] - c[c_start_id + j_2 - 1] * d[id_cur - shift] -
				b[c_start_id + j_2] * d[id_cur + shift]) / a[a_start_id + j_2];
		}
		else if (idx == 0)
		{
			d[id_cur] = (d[a_start_id] - b[c_start_id] * d[id_cur + shift]) / a[a_start_id];
		}
		else
		{
			d[id_cur] = (d[a_start_id + a_size - 1] - c[c_start_id + c_size - 1] * d[id_cur - shift]) 
				/ a[a_start_id + a_size - 1];
		}
	}
	else if (idx == I / 2) d[a_sum + I / 2] = d[a_sum - 1] / a[a_sum - 1];
}

__global__ void swapDArrElem(double* d, int I, int a_sum)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	if (idx < I)
	{
		d[idx] = d[a_sum + idx];
	}
}

void print_jagged_array(double* arr, int* sizes, int* start_ids, int q)
{
	for (int i = 0; i < q; ++i)
	{
		for (int j = start_ids[i]; j < start_ids[i] + sizes[i]; ++j)
		{
			cout << arr[j] << " ";
		}
		cout << endl;
	}
}

int main()
{
	// моделирование распространения тепла в однородном, теплоизолированном с боков, шаре
	double k_input = 0.59; // коэффициент теплопроводности
	double c_input = 1.65; // объёмная теплоёмкость
	double a_input = 0.6; // коэффициент температуропроводности
	double R_input = 6; // радиус шара

	double duration_input = 50; // время моделирования
	int q_input = 15; // двойка в степени для кол-ва уравнений
	int I = (1 << q_input) - 1; // кол-во уравнений – двойка в степени минус один
	int K = 5000; // кол-во временных слоёв

	bool is_print_values = false; // выводить ли вычисленные значения

	cout << "I = " << I << ", K = " << K << ", I * K = " << I * K << endl;

	double h_r = R_input / I;
	double h_t = duration_input / K;

	double* r_linspace = new double[I];
	for (int i = 0; i < I; ++i) {
		r_linspace[i] = i * R_input / (I - 1);
	}

	double* t_linspace = new double[K];
	for (int k = 0; k < K; ++k) {
		t_linspace[k] = k * duration_input / (K - 1);
	}

	double gamma = 6 * k_input / c_input * h_t / (h_r * h_r);
	double xi = 2 * k_input / c_input * h_t / h_r;
	double eta = k_input / c_input * h_t / (h_r * h_r);

	int* c_sizes = new int[q_input - 1];
	int* a_sizes = new int[q_input];

	int* c_start_ids = new int[q_input - 1];
	int* a_start_ids = new int[q_input];

	c_start_ids[0] = 0;
	a_start_ids[0] = 0;
	for (int i = 0; i < q_input; ++i)
	{
		int I_reduce = I >> i;

		if (i < q_input - 1) c_sizes[i] = I_reduce - 1;
		a_sizes[i] = I_reduce;
		if (i > 0)
		{
			if (i < q_input - 1) c_start_ids[i] = c_start_ids[i - 1] + c_sizes[i - 1];
			a_start_ids[i] = a_start_ids[i - 1] + a_sizes[i - 1];
		}
	}

	int c_sum = 0;
	int a_sum = 0;
	for (int i = 0; i < q_input; ++i)
	{
		if (i < q_input - 1) c_sum += c_sizes[i];
		a_sum += a_sizes[i];
	}

	// выделение памяти на CPU 
	double* c = new double[c_sum]; // нижняя диагональ
	double* a = new double[a_sum]; // главная диагональ
	double* b = new double[c_sum]; // верхняя диагональ
	double* d = new double[a_sum + I]; // правая часть (искомые неизвестные и начальное условие)

	// выделение памяти на GPU
	double* d_c; // нижняя диагональ
	double* d_a; // главная диагональ
	double* d_b; // верхняя диагональ
	double* d_d; // правая часть (искомые неизвестные и начальное условие)
	cudaMalloc(&d_c, c_sum * sizeof(double));
	cudaMalloc(&d_a, a_sum * sizeof(double));
	cudaMalloc(&d_b, c_sum * sizeof(double));
	cudaMalloc(&d_d, (a_sum + I) * sizeof(double));

	for (int i = 0; i < I; ++i) { // инициализация массивов
		if (i > 0 && i < I - 1)
		{
			c[i - 1] = -eta;
			a[i] = 1 + xi / r_linspace[i] + 2 * eta;
			b[i] = -(xi / r_linspace[i] + eta);
		}
		else if (i == 0)
		{
			a[0] = 1 + gamma;
			b[0] = -gamma;
		}
		else
		{
			c[I - 2] = -2 * eta - xi / R_input;
			a[I - 1] = 1 + xi / R_input + 2 * eta;
		}
		d[i] = 12 * exp(-pow((r_linspace[i] / a_input), 2));
	}

	// копируем данные на GPU
	cudaMemcpy(d_c, c, c_sum * sizeof(double), cudaMemcpyHostToDevice);
	cudaMemcpy(d_a, a, a_sum * sizeof(double), cudaMemcpyHostToDevice);
	cudaMemcpy(d_b, b, c_sum * sizeof(double), cudaMemcpyHostToDevice);
	cudaMemcpy(d_d, d, (a_sum + I) * sizeof(double), cudaMemcpyHostToDevice);

	ofstream file("dArray.txt");
	if (!file.is_open()) {
		cerr << "Error!\n";
		return 1;
	}
	for (int k = 0; k < K - 1; ++k) // суслик
	{
		int blockSize = 256;
		int gridSize = (I + blockSize - 1) / blockSize;

		cudaEvent_t start, stop;
		if (k == 0)
		{
			cudaEventCreate(&start);
			cudaEventCreate(&stop);
			cudaEventRecord(start);
		}

		for (int i = 0; i < q_input - 1; ++i) {
			forwardStepKernel << <gridSize, blockSize >> > (d_c, d_a, d_b, d_d,
				a_sizes[i], a_sizes[i + 1], c_sizes[i], a_start_ids[i], c_start_ids[i], k);
		}
		for (int i = q_input - 1, eq_use_count = 1; i >= 0; --i, eq_use_count <<= 1) {
			backStepKernel << <gridSize, blockSize >> > (d_c, d_a, d_b, d_d,
				a_sizes[i], c_sizes[i], a_start_ids[i], c_start_ids[i], a_sum, i, q_input, eq_use_count, I);
		}

		if (k == 0)
		{
			cudaEventRecord(stop);
			cudaEventSynchronize(stop);
			float total_time_ms;
			cudaEventElapsedTime(&total_time_ms, start, stop);
			cout << "Total execution time: " << total_time_ms << " ms\n";
			cudaEventDestroy(start);
			cudaEventDestroy(stop);
		}

		cudaMemcpy(d, d_d, (a_sum + I) * sizeof(double), cudaMemcpyDeviceToHost);

		if (k < K - 1)
		{
			swapDArrElem << < gridSize, blockSize >> > (d_d, I, a_sum);
		}
		cudaDeviceSynchronize();

		if (k == 0)
		{
			if (is_print_values)
			{
				cout << "c_array:\n"; // вывод нижней диагонали
				print_jagged_array(c, c_sizes, c_start_ids, q_input - 1);
				cout << "a_array:\n"; // вывод главной диагонали
				print_jagged_array(a, a_sizes, a_start_ids, q_input);
				cout << "b_array:\n"; // вывод верхней диагонали
				print_jagged_array(b, c_sizes, c_start_ids, q_input - 1);
				cout << "d_array:\n"; // вывод правой части
			}

			file << R_input << " " << I << " " << duration_input << " " << K << endl;
			for (int i = 0; i < I; ++i) file << d[i] << " ";
			file << endl;
		}
		if (is_print_values)
		{
			cout << "k = " << k << endl;
			print_jagged_array(d, a_sizes, a_start_ids, q_input);
		}

		for (int i = 0; i < I; ++i) file << d[a_sum + i] << " ";
		file << endl;
	}
	if (is_print_values)
	{
		cout << "k = " << K - 1 << endl;
		for (int i = 0; i < I; ++i) cout << d[a_sum + i] << " "; // вывод последнего слоя K
	}

	system("python graph.py");

	delete[] r_linspace;
	delete[] t_linspace;
	delete[] c;
	delete[] a;
	delete[] b;
	delete[] d;
	cudaFree(d_c);
	cudaFree(d_a);
	cudaFree(d_b);
	cudaFree(d_d);
	delete[] c_sizes;
	delete[] a_sizes;
	delete[] c_start_ids;
	delete[] a_start_ids;
}