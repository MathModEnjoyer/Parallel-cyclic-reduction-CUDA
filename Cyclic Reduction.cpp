#include <iostream>
#include <fstream>
#include <chrono>

using namespace std;

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
	int K = 500; // кол-во временных слоёв

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

	double* c = new double[c_sum]; // нижняя диагональ
	double* a = new double[a_sum]; // главная диагональ
	double* b = new double[c_sum]; // верхняя диагональ
	double* d = new double[a_sum + I]; // правая часть (искомые неизвестные и начальное условие)

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

	ofstream file("dArray.txt");
	if (!file.is_open()) {
		cerr << "Error!\n";
		return 1;
	}
	for (int k = 0; k < K - 1; ++k) // суслик
	{
		chrono::steady_clock::time_point start;
		if (k == 0) start = chrono::high_resolution_clock::now();
		for (int i = 0; i < q_input - 1; ++i) // прямой ход
		{
			for (int j = 0; j < a_sizes[i + 1]; ++j) // вычисление коэффициентов следующего этапа редукции
			{
				int id_prev = a_start_ids[i] + j * 2 + 1;       // предыдущие коэффициенты
				int id_prev_с = c_start_ids[i] + j * 2 + 1;     //
				int id_cur = a_start_ids[i] + a_sizes[i] + j;   // текущие коэффициенты
				int id_cur_c = c_start_ids[i] + c_sizes[i] + j; //

				double repeat_coef_1 = c[id_prev_с - 1] / a[id_prev - 1];
				double repeat_coef_2 = b[id_prev_с] / a[id_prev + 1];
				if (k == 0)
				{
					if (j > 0) c[id_cur_c - 1] = -repeat_coef_1 * c[id_prev_с - 2];

					a[id_cur] = a[id_prev] - repeat_coef_1 * b[id_prev_с - 1] - repeat_coef_2 * c[id_prev_с];

					if (j < a_sizes[i + 1] - 1) b[id_cur_c] = -repeat_coef_2 * b[id_prev_с + 1];
				}
				d[id_cur] = d[id_prev] - repeat_coef_1 * d[id_prev - 1] - repeat_coef_2 * d[id_prev + 1];
			}
		}
		for (int i = q_input - 1, eq_use_count = 1; i >= 0; --i, eq_use_count <<= 1) // обратный ход
		{
			if (i < q_input - 1)
			{
				int shift = 1 << i;
				for (int j = 0; j < eq_use_count; ++j)
				{
					int id_cur = a_sum + shift + j * (shift << 1) - 1;
					int j_2 = j * 2;
					if (j > 0 && j < eq_use_count - 1)
					{
						d[id_cur] = (d[a_start_ids[i] + j_2] -
							c[c_start_ids[i] + j_2 - 1] * d[id_cur - shift] -
							b[c_start_ids[i] + j_2] * d[id_cur + shift])
							/ a[a_start_ids[i] + j_2];
					}
					else if (j == 0)
					{
						d[id_cur] = (d[a_start_ids[i]] -
							b[c_start_ids[i]] * d[id_cur + shift])
							/ a[a_start_ids[i]];
					}
					else
					{
						d[id_cur] = (d[a_start_ids[i] + a_sizes[i] - 1] -
							c[c_start_ids[i] + c_sizes[i] - 1] * d[id_cur - shift])
							/ a[a_start_ids[i] + a_sizes[i] - 1];
					}
				}
			}
			else d[a_sum + I / 2] = d[a_sum - 1] / a[a_sum - 1];
		}
		if (k == 0)
		{
			auto end = chrono::high_resolution_clock::now();
			auto dur = end - start;
			cout << "Time taken: " << dur.count() << " nanoseconds\n";
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
		if (k < K - 1) for (int i = 0; i < I; ++i) d[i] = d[a_sum + i];
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
	delete[] c_sizes;
	delete[] a_sizes;
	delete[] c_start_ids;
	delete[] a_start_ids;
}