import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  String _category = 'length';

  double _value = 1.0;
  String _from = 'm';
  String _to = 'km';

  double _result = 0;

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  void _recalc() {
    double out = 0;

    if (_category == 'temperature') {
      out = _convertTemp(_value, _from, _to);
    } else {
      final fromFactor = _factor(_category, _from);
      final toFactor = _factor(_category, _to);
      // base = value * fromFactor
      // result = base / toFactor
      out = (_value * fromFactor) / toFactor;
    }

    setState(() => _result = out);
  }

  double _factor(String cat, String unit) {
    // factors to base unit:
    // length base: meter
    // weight base: kilogram
    if (cat == 'length') {
      switch (unit) {
        case 'mm':
          return 0.001;
        case 'cm':
          return 0.01;
        case 'm':
          return 1.0;
        case 'km':
          return 1000.0;
        case 'in':
          return 0.0254;
        case 'ft':
          return 0.3048;
        case 'yd':
          return 0.9144;
        case 'mi':
          return 1609.344;
      }
    } else if (cat == 'weight') {
      switch (unit) {
        case 'g':
          return 0.001;
        case 'kg':
          return 1.0;
        case 'lb':
          return 0.45359237;
        case 'oz':
          return 0.028349523125;
        case 't':
          return 1000.0;
      }
    }
    return 1.0;
  }

  double _convertTemp(double v, String from, String to) {
    double c;
    switch (from) {
      case 'c':
        c = v;
        break;
      case 'f':
        c = (v - 32) * 5 / 9;
        break;
      case 'k':
        c = v - 273.15;
        break;
      default:
        c = v;
    }

    switch (to) {
      case 'c':
        return c;
      case 'f':
        return (c * 9 / 5) + 32;
      case 'k':
        return c + 273.15;
      default:
        return c;
    }
  }

  List<String> _unitsFor(String cat) {
    if (cat == 'length') return ['mm', 'cm', 'm', 'km', 'in', 'ft', 'yd', 'mi'];
    if (cat == 'weight') return ['g', 'kg', 'lb', 'oz', 't'];
    return ['c', 'f', 'k'];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final categories = <String, String>{
      'length': t.convLength,
      'weight': t.convWeight,
      'temperature': t.convTemperature,
    };

    final units = _unitsFor(_category);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.tabConverter,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _category,
                    items: categories.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _category = v;
                        final u = _unitsFor(v);
                        _from = u.first;
                        _to = u.length > 1 ? u[1] : u.first;
                      });
                      _recalc();
                    },
                    decoration: InputDecoration(labelText: t.convCategory),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    initialValue: _value.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: t.convValue),
                    onChanged: (s) {
                      final v = double.tryParse(s.replaceAll(',', '.'));
                      if (v == null) return;
                      _value = v;
                      _recalc();
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _from,
                          items: units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _from = v);
                            _recalc();
                          },
                          decoration: InputDecoration(labelText: t.convFrom),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _to,
                          items: units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _to = v);
                            _recalc();
                          },
                          decoration: InputDecoration(labelText: t.convTo),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.calculate),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${t.convResult}: ${_result.toStringAsPrecision(8)}",
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
